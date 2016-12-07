#!/bin/bash

# Yet another BASH wrapper arpund ffmpeg for batch encodings.
# It has a few presets for different formats: web, DVD, Bluray, frames.
# And you can apply some generic options: noise removal,
# border, sharpening.
# It will encode all files in chosen folder. There is also option for test mode,
# where only small segment of clips is transcoded.

# Made by Miha Peče, ZRC-SAZU

#set -o errexit
#set -o pipefail
set -o nounset
#set -o xtrace



# Variable for source folder, defined with argument
declare SELEC_FOLDER
# Encoded files will be stored in subfolder
declare OUT_FOLDER="encodings"

# Transcoding presets
declare -a PRESETS

# Test mode
declare -a test_mode=("")
declare -i BEGIN=20 # From which second starts test encoding
declare -i AMOUNT=10 # How many seconds to test encode

# Stopwatch
declare ALL_TIME
declare START_TIME


echo "	    												    "
echo "  ########################################################"
echo "  #  Wraper arround ffmpeg, video-audio encodig library  #"
echo "  ########################################################"
echo "															"


#################################################################
####           Arguments and preparatory routines            ####
#################################################################

# Exit/usage function
function usage {
	tput setaf 2
	echo 
	echo "   ############################################"
	echo "   #  Mandatory arguments:                    #"
        echo "   #  -i/--input [FOLDER] [PRESET1] ...       #"
	echo "   #                                          #"
        echo "   #  Available encoding presets:             #"
	echo "   #  web                                     #"
	echo "   #  bluray                                  #"
	echo "   #  dvd                                     #"
	echo "   #  frames                                  #"
	echo "   #                                          #"
	echo "   #  You can use one or more presets         #"
	echo "   #  simultaneously,                         #"
	echo "   ############################################"
	echo 
	tput sgr0 # Reseting colors
	echo
	sleep 3
	exit 1
}

# Cheking if arguments were set
if [ ${#@} -eq 0 ]; then
	usage
fi

# First check for help
if [[ $1 == "-h" || $1 == "--help" ]]; then
	usage
fi


set +o nounset # Temporarly off
# All other arguments
while [ ${#@} -gt 0 ]; do
	key="$1"	
	case $key in
	    -i|--input)
	    	if [ -n "$2" ]; then
				SELEC_FOLDER="$2"
	    		shift
			else
				usage
			fi
	    	;;
	    *)
	        PRESETS+=("$key") 
	    	;;
	esac
	shift
done

set -o nounset

# Checking if folder was set
if [ "$SELEC_FOLDER" == "" ]; then
	usage
fi

# Cheking if any preset present
if [ ${#PRESETS[@]} -eq 0 ]; then
	usage
fi

# Validating presets
for var in ${PRESETS[@]}; do
	case "$var" in
		web|bluray|dvd|frames)
		    echo ""
			echo "  Argument $var is OK., proceeding with execution..."
			echo ""
			;;
		*) 
	    	echo ""
			echo "  Argument $var is not a relevant option."
			echo ""
			usage
			;;
	esac
done

if [ ${SELEC_FOLDER:(-1)} != "/" ]; then
	OUT_FOLDER="${SELEC_FOLDER}/${OUT_FOLDER}/"
else
	OUT_FOLDER="${SELEC_FOLDER}${OUT_FOLDER}/"
fi

# Checking folders
if [ ! -d "$SELEC_FOLDER" ]; then
	tput setaf 1
	echo
	echo "  #############################################"
	echo "  #   Folder with media files doesn't exists  #"
	echo "  #############################################"
	tput sgr0
	exit 1
fi

if [ ! -d "$OUT_FOLDER" ]; then
	mkdir "$OUT_FOLDER"
	
	# Checking if action succeeded
	if [ $? -ne 0 ]; then
		tput setaf 1
		echo
		echo "  #############################################"
		echo "  #      Something went wrong with mkdir      #"
		echo "  #############################################"
		tput sgr0
		exit 1
	fi
fi  												     


# Cheking if ffmpeg is installed
ffmpeg -h &> /dev/null

if [ $? -eq 0 ]; then
  	echo "  ####################"
	echo "  # ffmpeg installed #"
	echo "  ####################"
	echo ""
else
	tput setaf 1
	echo ""
	echo "  ########################"
	echo "  # ffmpeg seems missing #"
	echo "  ########################"
	tput sgr0
	echo
	exit 1
fi



#################################################################
####                      Menu options                       ####
#################################################################

# Batch, test mode or cobining two files
echo ""
echo "  Choose (b)atch mode for encoding 1 or many files or"
echo "  (t)est mode for encoding only short segment of clips:"
echo "  b/t"
tput cuf 2 # Moving sursor 2 spaces right for better style
read -n 1 -s reply

case "$reply" in
	b)
		echo ""
		echo "  $(tput setaf 2)b$(tput sgr0) ... one/many files in folder."
		echo ""
		batch=1
		;;
	t)
		echo ""
		echo "  $(tput setaf 2)t$(tput sgr0) ... test mode, a segment of file(s)."
		echo ""
		batch=1
		test_mode=("-ss" ${BEGIN} "-t" ${AMOUNT})
		;;

	*)
		tput setaf 1
		echo ""
		echo "  Wrong option, terminating script."
		tput sgr0 
		echo
		exit 1
		;;
esac

sleep 1.5


# Additional ffmpeg settings, noise filter
echo ""
echo "  Do you want remove noise from image:"
echo "  y/n"
tput cuf 2
read -n 1 -s reply

case "$reply" in
	n)
		echo ""
		echo "  $(tput setaf 2)n$(tput sgr0) ... coding without de-noise filter."
		echo ""
		noise=0
		;;
	y)
		echo ""
		echo "  $(tput setaf 2)y$(tput sgr0) ... using de-noise filter."
		echo ""
		noise=1
		;;
	*)
		tput setaf 1
		echo ""
		echo "  Wrong option, terminating script."
		tput sgr0 # Reseting colors
		exit 1
		;;
esac

sleep 1.5

# Additional filter: image border
echo ""
echo "  Do you want image with border:"
echo "  y/n"
tput cuf 2
read -n 1 -s reply

case "$reply" in
	n)
		echo ""
		echo "  $(tput setaf 2)n$(tput sgr0) ... coding without border filter."
		echo ""
		border=0
		;;
	y)
		echo ""
		echo "  $(tput setaf 2)y$(tput sgr0) ... using border filter."
		echo ""
		border=1
		;;
	*)
		tput setaf 1
		echo ""
		echo "  Wrong option, terminating script."
		tput sgr0
		exit 1
		;;
esac

sleep 1.5

# Additional filter: sharpening image
echo ""
echo "  Do you want sharpen image:"
echo "  y/n"
tput cuf 2
read -n 1 -s reply

case "$reply" in
	n)
		echo ""
		echo "  $(tput setaf 2)n$(tput sgr0) ... coding without unsharp filter."
		echo ""
		sharpen=0
		;;
	y)
		echo ""
		echo "  $(tput setaf 2)y$(tput sgr0) ... using unsharp filter."
		echo ""
		sharpen=1
		;;
	*)
		tput setaf 1
		echo ""
		echo "  Wrong option, terminating script."
		tput sgr0
		exit 1
		;;
esac

sleep 1.5

# Additional audio filter: channel muxing
echo ""
echo "  Do you want to mux audio channels:"
echo "  y/n"
tput cuf 2
read -n 1 -s reply

case "$reply" in
	n)
		echo ""
		echo "  $(tput setaf 2)n$(tput sgr0) ... coding without muxing audio channels."
		echo ""
		channels=0
		;;
	y)
		echo ""
		echo "  $(tput setaf 2)y$(tput sgr0) ... muxung audio channels."
		echo ""
		channels=1
		;;
	*)
		tput setaf 1
		echo ""
		echo "  Wrong option, terminating script."
		tput sgr0
		exit 1
		;;
esac

sleep 1.5


#################################################################
####                 Encoding functions                      ####
#################################################################
	
function encode_web {
	# Defining/Reseting variables
	local -a filter
	local -a tmp_array
	local tmp_string
	local -a audio_filter
	
	# ffmpeg filters, order is important!
	# (deinterlace -> denoise -> scaling is usually best sequence)
	
	# Deinterlace is mandatory here. It checks first,
	# if file is progressive, and execute only if
	# response is negative
	tmp_array=("yadif=0:-1:0")
	
	# Additional options: darker, lighter, linear_contrast,
	# medium_contrast, strong_contrast, negative, color_negative
	#tmp_array+=("curves=color_negative")
	
	# default:4.0:3.0:6.0:4.5
	if [ $noise -eq 1 ]; then 
		tmp_array+=("hqdn3d=7.0:3.0:6.0:4.5")
	fi

	# interl: 1 is forced interlaced scaling, -1 is automatic, 0 progressive
	# Instead on relying on pixel aspect (SAR), global resolutin is adjusted 
	tmp_array+=("scale='if(eq(1,sar),iw,dar*ih)':ih:interl=0") 
	
	if [ $sharpen -eq 1 ]; then
		tmp_array+=("unsharp=7:7:2.5:7:7:2.5") #Default:7:7:2.5:7:7:2.5
	fi

	if [ $border -eq 1 ]; then
		tmp_array+=("drawbox=t=7:color=black")
	fi

	if [ ${#tmp_array[@]} -gt 0 ]; then
		for i in ${tmp_array[@]}; do
			tmp_string+="$i"
			tmp_string+=", "
		done
		tmp_string=${tmp_string%??} #Delete last two chars
		filter=("-vf" "$tmp_string")
	fi
	
	# audio channel muxing
	if [ $channels -eq 1 ]; then 
		audio_filter=("-af" "pan=stereo|c0<c0+c1|c1<c0+c1")
	fi
	
   	ffmpeg ${test_mode[@]} ${f[@]} ${filter[@]} -movflags +faststart -c:v libx264 -pix_fmt yuv420p -preset medium -crf 26 -c:a aac -strict experimental -b:a 96k -ar 44100 ${audio_filter[@]} -y "${OUT_FOLDER}${f[1]##*/}.web_output.mp4"
   	# faststart: moving metadata on beginning for quick start
   	# preset: for testing use ultrafast, for on-line quality slow or slower or veryslow
   	# crf: 23 is default value, 18 is visualy loosless
   	# -pix_fmt yuv420p: Apple compatibility, 422 is not suported
	# pan=stereo|c0<c0+c1|c1<c0+c1: remuxing stereo channels
	
	# Checking if everything went OK
	if [ $? -ne 0 ]; then
		tput setaf 1
		tput setab 2
		echo
		echo "  #############################################"
		echo "  #  Something went wrong encoding web file!  #"
		echo "  #############################################"
	else
		tput setaf 4
		tput setab 2
		echo 
		echo "  ###########################"
		echo "  #  Web encoding finished  #"
		echo "  ###########################"
	fi
	tput sgr0
	echo
}
	
function encode_bluray {
	# Defining variables
	local -a filter
	local -a tmp_array
	local tmp_string
	
	if [ $noise -eq 1 ]; then 
		tmp_array+=("hqdn3d=10.0:3.0:10.0:4.5")
	fi
	
	if [ $sharpen -eq 1 ]; then
		tmp_array+=("unsharp=7:7:2.5:7:7:2.5") #Default:7:7:2.5:7:7:2.5
	fi

	if [ $border -eq 1 ]; then
		tmp_array+=("drawbox=t=5:color=black")
	fi
	
	if [ ${#tmp_array[@]} -gt 0 ]; then
		for i in ${tmp_array[@]}; do
			tmp_string+="$i"
			tmp_string+=", "
		done
		tmp_string=${tmp_string%??} #Delete last two chars
		filter=("-vf" "$tmp_string")
	fi
	
	ffmpeg ${test_mode[@]} ${f[@]} ${filter[@]} -c:v libx264 -b:v 35M -maxrate 40M -bufsize 30M -pix_fmt yuv420p -preset medium -tune film -level 4.1 -x264opts keyint=25:b-pyramid=strict:bluray-compat=1:force-cfr=1:weightp=0:bframes=3:ref=3:open-gop=1:slices=4:tff=1:aud=1:colorprim=bt709:transfer=bt709:colormatrix=bt709:sar=1/1 -r 25 -an -y "${OUT_FOLDER}${f[1]##*/}.bluray_output.264" -c:a ac3 -b:a "320k" -ar 48000 -y "${OUT_FOLDER}${f[1]##*/}.bluray_output.ac3"
	
	# Checking if everything went OK
	if [ $? -ne 0 ]; then
		tput setaf 1
		tput setab 2
		echo
		echo "  ###################################################"
		echo "  #  Something went wrong encoding bluray streams!  #"
		echo "  ###################################################"
	else
		tput setaf 4
		tput setab 2
		echo 
		echo "  ##############################"
		echo "  #  Bluray encoding finished  #"
		echo "  ##############################"
	fi
	tput sgr0
	echo	
}
	
function encode_dvd { 
	# Defining variables
	local -a filter
	local -a tmp_array
	local tmp_string
	local tmp_file
	local -a audio_filter
	
	if [ $noise -eq 1 ]; then 
		tmp_array+=("hqdn3d=10.0:3.0:10.0:4.5") # Derfoult value: "hqdn3d=10.0:3.0:10.0:4.5": remove noise in image
	fi
	
	tmp_array+=("scale=720:576:interl=-1") # interl: 1 is forced interlaced scaling, -1 is automatic, 0 progressive
	
	if [ $sharpen -eq 1 ]; then
		tmp_array+=("unsharp=7:7:2.5:7:7:2.5") #Default:7:7:2.5:7:7:2.5
	fi
	
	if [ $border -eq 1 ]; then
		tmp_array+=("drawbox=t=5:color=black")
		# Draw border 5px wide
	fi
	
	# Combine all filter options
	if [ ${#tmp_array[@]} -gt 0 ]; then
		for i in ${tmp_array[@]}; do
			tmp_string+="$i"
			tmp_string+=", "
		done
		tmp_string=${tmp_string%??} #Delete last two chars
		filter=("-vf" "${tmp_string}")
	fi
	
	# audio channel muxing
	if [ $channels -eq 1 ]; then 
		audio_filter=("-af" "pan=stereo|c0<c0+c1|c1<c0+c1")
	fi
	
	# First AC3 audio
	ffmpeg ${test_mode[@]} -i "${f[1]}" -acodec ac3 -b:a 192000 -ar 48000 ${audio_filter[@]} -y "${OUT_FOLDER}${f[1]##*/}.dvd_output.ac3"
	
	# Temporary outout file
	tmp_file="${f[1]}.temp.m2v"

	# 1. pass
	ffmpeg ${test_mode[@]} ${f[@]} -c:v mpeg2video -f dvd -s 720x576 -r 25 -pix_fmt yuv420p -g 15 -b:v 4100k -maxrate 8000000 -minrate 1500k -bufsize 1835008 -packetsize 2048 -pass 1 -an -y /dev/null

	# 2. pass
	ffmpeg ${test_mode[@]} ${f[@]} ${filter[@]} -c:v mpeg2video -f dvd -r 25 -pix_fmt yuv420p -g 15 -flags +ildct+ilme -b:v 5100k -maxrate 8000000 -minrate 1000000 -bufsize 1835008 -packetsize 2048 -muxrate 10080000 -pass 2 -an -y "${tmp_file}"
	# -flags +ildct+ilme: without this command output is progressive
	
	# Extract video stream (DVD Studio Pro compatability)
	ffmpeg -i "${tmp_file}" -c:v copy "${OUT_FOLDER}${f[1]##*/}.dvd_output.m2v"
	
	# Checking if everything went OK
	if [ $? -ne 0 ]; then
		tput setaf 1
		tput setab 2
		echo
		echo "  ################################################"
		echo "  #  Something went wrong encoding dvd streams!  #"
		echo "  ################################################"
	else
		tput setaf 4
		tput setab 2
		echo 
		echo "  ###################################"
		echo "  #  DVD streams encoding finished  #"
		echo "  ###################################"
	fi
	tput sgr0
	echo
	
	if [ -f "$tmp_file" ]; then
		rm "$tmp_file"
	fi
	
}

function extract_frames {
	# Defining variables
	local -a filter
	local -a tmp_array
	local tmp_string
	local IMG_OUT_FOLDER
	
	IMG_OUT_FOLDER="${OUT_FOLDER}/${f[1]##*/}"
	mkdir "$IMG_OUT_FOLDER"
	
	# Checking if action succeeded
	if [ $? -ne 0 ]; then
		tput setaf 1
		echo
		echo "  #############################################"
		echo "  #   Something went wrong with 2. mkdir      #"
		echo "  #############################################"
		tput sgr0
		exit 1
	fi
	
	# Deinterlace is mandatory here. It checks first,
	# if file is progressive, and execute only if
	# response is negative
	tmp_array=("yadif=0:-1:0")
	
	# default:4.0:3.0:6.0:4.5
	if [ $noise -eq 1 ]; then 
		tmp_array+=("hqdn3d=7.0:3.0:6.0:4.5")
	fi

	# interl: 1 is forced interlaced scaling, -1 is automatic, 0 progressive
	# Instead on relying on pixel aspect (SAR), global resolutin is adjusted 
	tmp_array+=("scale='if(eq(1,sar),iw,dar*ih)':ih:interl=0") 
	
	# For extracted frames some sherpening is always benefical,
	# so this optin is hard-coded 
	tmp_array+=("unsharp=7:7:2.5:7:7:2.5") #Default:7:7:2.5:7:7:2.5

	if [ $border -eq 1 ]; then
		tmp_array+=("drawbox=t=7:color=black")
	fi

	if [ ${#tmp_array[@]} -gt 0 ]; then
		for i in ${tmp_array[@]}; do
			tmp_string+="$i"
			tmp_string+=", "
		done
		tmp_string=${tmp_string%??} #Delete last two chars
		filter=("-vf" "$tmp_string")
	fi
	
   	ffmpeg -ss 60 ${f[@]} ${filter[@]} -r 1/60 -vframes 20 -y "${IMG_OUT_FOLDER}/${f[1]##*/}.%02d-frame.jpg"
   	# -ss 60: starting after 60 sec
   	# -r 1/60 extracting frame after every 1 min
   	# -vframes 20: repeating process 20-times 
   	# (if clip is shorter then cca. 20 min., program will stop without error)
	
	# Checking if everything went OK
	if [ $? -ne 0 ]; then
		tput setaf 1
		tput setab 2
		echo
		echo "  #############################################"
		echo "  #  Something went wrong encoding web file!  #"
		echo "  #############################################"
	else
		tput setaf 4
		tput setab 2
		echo 
		echo "  ###########################"
		echo "  #  Web encoding finished  #"
		echo "  ###########################"
	fi
	tput sgr0
	echo

}

###############################################
#### Main loop, calling encoding functions ####
###############################################

START_TIME=$(date +%s)

for selec_file in "${SELEC_FOLDER}"*; do
	
	# Conditions
	# If folder, load next file
	if [ -d "$selec_file" ]; then
		continue
	fi

	# If not regular file, break
	if [ ! -f "$selec_file" ]; then
	  	echo "  ${selec_file} file is not a regular file"
		usage
	fi

	# If empty file, break
	if [ ! -s "$selec_file" ]; then
	  	echo "  ${selec_file} file has 0 bits"
	    usage
	fi

	# ffmpeg input flag + file
	f=("-i" "$selec_file")
	
	# Main loop
	for var in ${PRESETS[@]}; do	
		echo
		echo -n "  Processing $(tput setaf 2)${f[1]} $(tput sgr0)file "; 
		
		# Animation, functioning as pause
		for num in {1..7}; do
			sleep 0.8;
			echo -n ".";
		done
		echo ""
		tput sgr0
		
		# Change internal field separator, so that we can use
		# also file names with spaces
		OLDIFS=$IFS
		IFS=$'\n'
		
		case "$var" in
			web)
				encode_web
			   	;;
			bluray)
				encode_bluray
				;;
			dvd)
				encode_dvd
				;;
			frames)
				extract_frames
				;;
		esac			
		
		IFS=$OLDIFS
	done
done

tput sgr0

ALL_TIME=$(date +%s)
ALL_TIME=$(( $ALL_TIME - $START_TIME ))

echo
echo -n "Process duration: "
printf "%02d:" $(( $ALL_TIME / 3600 ))
printf "%02d:" $(( ($ALL_TIME % 3600) / 60 ))
printf "%02d\n" $(( $ALL_TIME % 60 ))
echo
