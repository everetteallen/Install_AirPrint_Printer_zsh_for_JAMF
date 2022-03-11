#!/bin/zsh

# Use the built-in ipp2ppd tool to create a PPD file for AirPrint
# Add icon to PPD (if we can get one) and install the printer
# Credit apizz (https://gist.github.com/apizz/5ed7a944d8b17f28ddc53a017e99cd35)
# for the origional bash script
# Updated to zsh by Everette_Allen@ncsu.edu for use with JAMF Script Variables

# testing

4=""

# Required printer info
# This will need to be an IP Address or a fully qualified DNS Name
if [ ! -z "$4" ]; then
    PRINTER_IP="$4"
else
    echo "IP Address or DNS name of Printer Not Found.  Please check script variables."
    exit 1
fi

if [ ! -z "$5" ]; then
    PRINTER_NAME="$5"
else
    PRINTER_NAME="$4"
fi

if [ ! -z "$6" ]; then
    PRINTER_DISPLAY_NAME="$6"
else
    PRINTER_DISPLAY_NAME="$4"
fi

if [ ! -z "$7" ]; then
    PRINTER_LOCATION="$7"
else
    PRINTER_LOCATION="$4"
fi
## End Required printer info
#
# Requiring icon will prevent install if we can't get it
# Set this to the string true or false not a bool
if [[ ! -z "$8" ]; then
    REQUIRE_ICON="$8"
else
    REQUIRE_ICON="false"
if
# Number of seconds to wait for TCP verification before exiting
CHECK_TIMEOUT=2
# Custom PPD info
PPD_PATH='/tmp'
PPD="${PPD_PATH}/${PRINTER_NAME}.ppd"
# Base info
AIR_PPD='/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/PrintCore.framework/Versions/A/Resources/AirPrint.ppd'
EXE='/System/Library/Printers/Libraries/ipp2ppd'
ICON_PATH='/Library/Printers/Icons'
ICON="${ICON_PATH}/${PRINTER_NAME}.icns"

AppendPPDIcon() {
	# Verify we have a file
	if [ ! -f "$ICON" ] && [ "$ICON_AVAILABLE" != "false" ]; then
		/bin/echo "Don't have an icon. Exiting…"
		exit 1
	fi

	/bin/echo "Appending ${ICON} to ${PPD}…"
	# Append the icon to the PPD
	/bin/echo "*APPrinterIconPath: \"${ICON}\"" >> "${PPD}"
}

CheckPrinter() {
	# Verify we can communicate with the printer via the AirPrint port via TCP
	local CHECK=$(/usr/bin/nc -G ${CHECK_TIMEOUT} -z ${PRINTER_IP} 631 2&> /dev/null; /bin/echo $?)

	if [ "$CHECK" != 0 ]; then
		/bin/echo "Cannot communicate with ${PRINTER_IP} on port 631/tcp. Exiting…"
		exit 1
	fi
}

CheckIcon() {
	# Query & parse printer icon, largest usually last?
	PRINTER_ICON=$(/usr/bin/ipptool -tv ipp://${PRINTER_IP}/ipp/print get-printer-attributes.test \
	| /usr/bin/awk -F, '/printer-icons/ {print $NF}')

	# Verify we have an icon to download
	if [ -z "$PRINTER_ICON" ] && [ "$REQUIRE_ICON" = "true" ]; then
		/bin/echo "Did not successfully query a printer icon. Will not install printer. Exiting…"
		exit 1
	elif [ -z "$PRINTER_ICON" ]; then
		/bin/echo "Did not successfully query printer icon. Will continue with printer install…"
		ICON_AVAILABLE=false
	fi

	/bin/echo "Downloading printer icon from ${PRINTER_ICON} to ${ICON}…"
	# Download the PNG icon and make it an .icns file
	/usr/bin/curl -skL "$PRINTER_ICON" -o "$ICON"
	
	# Did we actually write an icon successfully?
	STATUS=$(echo $?)
	if [[ "${STATUS}" != 0 ]]; then
		/bin/echo ""
		/bin/echo "Was not able to write the file ${ICON}…"
		/bin/echo "Does the user running this script have the ability to write to ${ICON_PATH}?"
		/bin/echo "If not, either run with 'sudo' or choose a different location to write the icon file."
		exit 1 
	fi
}

CreatePPD() {
	# Create the PPD file
	/bin/echo "Creating the .ppd file at ${PPD}…"
	$EXE ipp://${PRINTER_IP} "$AIR_PPD" > "$PPD"
}

InstallPrinter() {
	/bin/echo "Installing printer…"
	/usr/sbin/lpadmin -p ${PRINTER_NAME} -D "${PRINTER_DISPLAY_NAME}" -L "${PRINTER_LOCATION}" -E -v ipp://${PRINTER_IP} -P ${PPD} -o printer-is-shared=false
}

main() {
	CheckPrinter
	CreatePPD
	if [ $REQUIRE_ICON == "true"] then;
	    CheckIcon
	    AppendPPDIcon
	fi
	InstallPrinter
}

main "@"