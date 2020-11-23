#!/bin/bash
#Maintained by Ruben Calzadilla
#version 1.92
#VideoFlow DVG or Linux
#Dependancy: FFmpeg
#Creates a UDP stream with Customized SMPTE Color Bars and one audio pair for testing
#
#

version="1.92"

#This hash value is used to make the ffmpeg command unique and therefore able to grep on the
#FFmpeg streams created by this script only. The hash is use on a metadata statement for network id
#- metadata mpegts_original_network_id="${hash}"
hash="0x0ACE"

opt=$1
sys=$2

if [[ -z $sys ]] || [[ $sys == "dvp" ]]; then
    let dvp=1
    system="DVG"
elif [[ $sys == "lnx" ]]; then
    let dvp=0
    system="Linux"
    type ffmpeg > /dev/null 2>&1
    if [[ $? -eq 1 ]]; then
        echo " "
        echo "FFmpeg is not installed on this system, or it needs to be added to the system PATH"
        echo " "
        exit 5
    fi
else
    echo " "
    echo "Wrong system parameter, options are dvp or lnx"
    echo " "
    exit 23
fi

#Functions Declaration
ffmpeg_stream () {
    MV=$(echo ${MXO} | awk '{print $1-1}')

    if [[ $MV -le 1 ]]; then
        echo " "
        echo "Mux rate is too low, Mux rate should be > 2Mbps"
        echo " "
        exit 5
    fi
    
    if [[ $dvp -eq 1 ]]; then
        /dvp100/ffmpeg/ffmpeg -re -fflags +genpts -f lavfi -i smptehdbars=size=${EncRes}:rate=${Frate} -f lavfi -i sine=frequency=440:beep_factor=4 -f lavfi -i sine=frequency=440:beep_factor=4 \
-vf "drawtext=fontfile=/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf:fontsize=82:fontcolor=white:timecode='00\:00\:00\:00':timecode_rate=${Frate}:x=(w-text_w)/2:y=(h-text_h)/2",\
"drawtext=fontfile=/usr/share/fonts/dejavu/DejaVuSans.ttf:fontsize=22:fontcolor=white:text='PTS %{pts}':x=30:y=30",\
"drawtext=fontfile=/usr/share/fonts/dejavu/DejaVuSans.ttf:fontsize=42:fontcolor=white:text=\[V\]\[2\]:x=(w-text_w)/2:y=(h-text_h)/2+100",\
"drawtext=fontfile=/usr/share/fonts/dejavu/DejaVuSans.ttf:fontsize=42:fontcolor=white:text='%{localtime\:%H %M %S}':x=(w-text_w)/2:y=(h-text_h)/2-200",\
"drawtext=fontfile=/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf:fontsize=92:fontcolor=${STXC}:text='${STX}':x='w-w/30*mod(t,30*(w+tw)/w)':y=(h-text_h)/2-280" \
-filter_complex "[1:a][2:a]join=inputs=2[a0]" -map 0:v -map "[a0]" -c:v ${LibEnc} -g ${GOPS} -b:v ${MV}M -minrate ${MV}M -maxrate ${MV}M -muxrate ${MXO}M  -preset veryfast -pix_fmt yuv420p \
-metadata service_provider="Intelsat" -metadata service_name="Intelsat_Test" -metadata mpegts_original_network_id="${hash}" -f mpegts "udp://${IPO}:${PO}?pkt_size=1316" > /dev/null 2>&1 < /dev/null &
    elif [[ $dvp -eq 0 ]]; then
#For linux system with FFmpeg installed
        ffmpeg -re -fflags +genpts -f lavfi -i smptehdbars=size=${EncRes}:rate=${Frate} -f lavfi -i sine=frequency=440:beep_factor=4 -f lavfi -i sine=frequency=440:beep_factor=4 \
-vf "drawtext=fontfile=/usr/share/fonts/truetype/freefont/DejaVuSansBold.ttf:fontsize=82:fontcolor=white:timecode='00\:00\:00\:00':timecode_rate=${Frate}:x=(w-text_w)/2:y=(h-text_h)/2",\
"drawtext=fontfile=/usr/share/fonts/truetype/freefont/DejaVuSans.ttf:fontsize=22:fontcolor=white:text='PTS %{pts}':x=30:y=30",\
"drawtext=fontfile=/usr/share/fonts/truetype/freefont/DejaVuSans.ttf:fontsize=42:fontcolor=white:text=\[V\]\[2\]:x=(w-text_w)/2:y=(h-text_h)/2+100",\
"drawtext=fontfile=/usr/share/fonts/truetype/freefont/DejaVuSans.ttf:fontsize=42:fontcolor=white:text='%{localtime\:%H %M %S}':x=(w-text_w)/2:y=(h-text_h)/2-200",\
"drawtext=fontfile=/usr/share/fonts/truetype/freefont/DejaVuSansBold.ttf:fontsize=92:fontcolor=${STXC}:text='${STX}':x='w-w/30*mod(t,30*(w+tw)/w)':y=(h-text_h)/2-280" \
-filter_complex "[1:a][2:a]join=inputs=2[a0]" -map 0:v -map "[a0]" -c:v ${LibEnc} -g ${GOPS} -b:v ${MV}M -minrate ${MV}M -maxrate ${MV}M -muxrate ${MXO}M  -preset veryfast -pix_fmt yuv420p \
-metadata service_provider="Intelsat" -metadata service_name="Intelsat_Test" -metadata mpegts_original_network_id="${hash}" -f mpegts "udp://${IPO}:${PO}?pkt_size=1316" > /dev/null 2>&1 < /dev/null &
    fi
    
    echo " "
    echo "Creating the stream ......"
    sleep 4

    PID=`ps -ef | grep -v grep | grep ffmpeg | grep -e "${hash}" | grep -e "${IPO}:${PO}" | awk '{print $2}'`

    if [[ -z $PID ]]; then
        echo " "
        echo "ERROR: FFMPEG Stream did not START. Check that your target system is correct"
        echo " "
        exit 5
    else
        echo " "
        echo "FFMPEG Stream Started on ${IPO}:${PO} at ${MXO}Mbps CBR"
        echo "This Stream is using Process_ID: $PID"
        echo " "
        exit 0
    fi

}

ffmpeg_stop () {
    PID=`ps -ef | grep -v grep | grep ffmpeg | grep -e "${hash}" | grep -e "${IPO}:${PO}" | awk '{print $2}'`
    if [[ -z $PID ]]; then
        echo " "
        echo "ERROR: The FFMPEG stream with IP:Port ${IPO}:${PO} does not exist"
        echo " "
        exit 5
    else
        kill -9 $PID > /dev/null 2>&1
        echo " "
	    echo "FFMPEG Stream using ${IPO}:${PO} is Stopped"
        echo " "
        exit 0
    fi
}

createStream () {
    echo " "
    echo "Configuration Parameters for a [ $system ] System"
    echo " "
    echo "Stream IP Output: "
    read IPO
    if [[ -z ${IPO} ]]; then
        echo " "
        echo "ERROR: The Output IP address is not valid"
        echo " "
        exit 5
    fi

    echo "Stream UDP Port: "
    read PO
    if [[ -z ${PO} ]]; then
        echo " "
        echo "ERROR: The PORT number is not valid"
        echo " "
        exit 5
    fi

    echo "Mux Output Bit-rate (Mbps): "
    read MXO
    if [[ -z ${MXO} ]]; then
        echo " "
        echo "ERROR: The Output Bit-Rate is not valid"
        echo " "
        exit 5
    fi

    echo " "
    echo "Encoder Parameters [default]"
    #echo " "
    printf "Encoder h264 or h265 [h264]: "
    read ENC
    if [[ -z ${ENC} ]]; then
        ENC="h264"
    fi

    echo ${ENC}
    if [[ ${ENC} == "h264" ]]; then
        LibEnc="libx264"
    elif [[ ${ENC} == "h265" ]]; then
        LibEnc="libx265"
        echo "WARNING: H265 encode will require more CPU processing than h264,"
        echo "and other processes in the system maybe impacted"
        echo " "
    else
        echo " "
        echo "ERROR: Need a valid Encoder"
        echo " "
        exit 5
    fi

    printf "Resolution 720, 1080 or 4K [1080]: "
    read ENCR
    if [[ -z ${ENCR} ]]; then
        ENCR="1080"
    fi

    echo ${ENCR}
    if [[ ${ENCR} == "1080" ]]; then
        EncRes="1920x1080"
    elif [[ ${ENCR} == "4k" ]] || [[ ${ENCR} == "4K" ]]; then
        EncRes="3840x2160"
        echo "WARNING: 4K encode will require more CPU processing than HD,"
        echo "and other processes in the system maybe impacted"
        echo " "
    elif [[ ${ENCR} == "720" ]]; then
        EncRes="1280x720"
    else
        echo " "
        echo "ERROR: Need a valid Encoder Video Resolution"
        echo " "
        exit 5
    fi

    printf "Frame-Rate (fps) 25, 30 or 24 [30]: "
    read Frate
    if [[ -z ${Frate} ]]; then
        Frate="30"
    fi
    if [[ ${Frate} != "30" ]] && [[ ${Frate} != "24" ]] && [[ ${Frate} != "25" ]]; then
        echo " "
        echo "ERROR: Need a valid Encoder Video Frame-Rate: 24, 25 or 30 fps"
        echo " "
        exit 5
    fi

    echo ${Frate}

    #FFmpeg GOP Size = 2 * Frame-Rate
    GOPS=$(echo ${Frate} | awk '{print $1*2}')

    printf "Scrolling Text [Intelsat]: "
    read STX
    if [[ -z ${STX} ]]; then
        STX="Intelsat"
    fi

    echo ${STX}
    echo "Scrolling text color [white] "
    printf "options: white, blue, red, black and yellow: "
    read STXC
    if [[ -z ${STXC} ]]; then
        STXC="white"
    fi

    echo ${STXC}


    PID=`ps -ef | grep -v grep | grep ffmpeg | grep -e "${hash}" | grep -e "${IPO}:${PO}" | awk '{print $2}'`

    if ! [[ -z $PID ]]; then
        echo " "
        echo "ERROR: Another Stream with the same IP:PORT parameters is already configured"
        echo " "
        exit 5
    fi

    echo " "
    echo "To STOP the stream, please launch this app with the -d flag"
    echo " "

    echo "Creating a Video Stream [ Intelsat Color Bars ] --> [ ${IPO}:${PO} ] at [ ${MXO} ] Mbps"
    echo "Press Y/y to create the stream or N/n to exit"
    read ANS
    if [[ "$ANS" == "y" ]] || [[ "$ANS" == "Y" ]]; then
    	ffmpeg_stream
    else
        echo " "
        echo "Exiting, nothing was done!"
        echo " "
    	exit 4
    fi
}

deleteStream () {
    if [ $nst -eq 1 ]; then
        let nn=1
    else
        echo "Which Stream do you want to Stop, enter the number as listed above: "
        read nn
        nn=$(echo $nn | awk '{print $1*1}')
    fi
    echo " "
    IPO=$(echo ${IPO[$nn]})
    PO=$(echo ${PO[$nn]})
    echo "Stoping a Video Stream using [ ${IPO}:${PO} ]"
    echo "Press Y/y to stop the stream or N/n to exit"
    read ANS
    if [[ "$ANS" == "y" ]] || [[ "$ANS" == "Y" ]]; then
    	ffmpeg_stop
    else
        echo " "
        echo "Exiting, nothing was done!"
        echo " "
    	exit 4
    fi
}

listStreams () {
    nst=`ps -ef | grep -v grep | grep ffmpeg | grep -e "${hash}" | awk '{print $59}' | cut -d\? -f1 | wc -l | awk '{print $1}'`
    nst=$(echo ${nst} | awk '{print $1*1}')
    strms=(`ps -ef | grep -v grep | grep ffmpeg | grep -e "${hash}" | awk '{print $59}' | cut -d\? -f1`)
    mbps=(`ps -ef | grep -v grep | grep ffmpeg | grep -e "${hash}" | awk '{print $46}' | cut -d\M -f1`)
    
    echo " "

    if [[ $nst -eq 0 ]]; then
        echo "There are NO streams currently configured in the system"
        echo " "
        exit 0
    fi

    if [[ $nst -eq 1 ]]; then
        echo "There is only [ 1 ] stream configured as follows:"
    else
        echo "There are [ ${nst} ] streams configured as follows:"
    fi

    for (( cint=1 ; cint<=${nst} ; cint++ ))
    do
    echo "${cint}: ${strms[$cint - 1]} at ${mbps[$cint - 1]}Mbps"
    IPO[$cint]=$(echo ${strms[$cint - 1]} | cut -d\: -f2 | cut -d\/ -f3)
    PO[$cint]=$(echo ${strms[$cint - 1]} | cut -d\: -f3)
    done
    echo " "
}


if [[ "$opt" == "-c" ]]; then
    clear
	createStream
	exit 0
elif [[ "$opt" == "-d" ]]; then
    clear
    listStreams
    deleteStream
    exit 0
elif [[ "$opt" == "-l" ]]; then
    clear
    listStreams
    exit 0
fi

clear
echo " "
echo "-------------------------------------------------------------"
echo "| Generate_Bars script version v${version}                        |"
echo "| This script will generate a custumisable SMPTE Color Bars |"
echo "| as a CBR MPEG-TS over UDP Stream                          |"
echo "-------------------------------------------------------------"
echo " "
echo "Use:"
echo "          -c to Create a stream with the option for dvp or lnx"
echo "          -d to Delete an existing stream"
echo "          -l to List the number of existing streams"
echo " "
echo "examples:"
echo "          generate_bars -c dvp (VideoFlow specific)"
echo "          generate_bars -c lnx (Generic Linux OS)"
echo "          generate_bars -d"
echo "          generate_bars -l"
echo " "
echo "Dependancies:"
echo "          - FFMPEG"
echo " "
exit 0



