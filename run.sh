#!/bin/bash

# ? Collector Radio stream URL
STREAM_URL="https://ouifm6.ice.infomaniak.ch/collector-rnt.mp3?ua=COLLECTOR%20Radio%20-%20audio%20player"

# ? Restart counter
restart_count=0

# ? Buffer size in milliseconds (increase for unstable connections)
BUFFER_SIZE=20000

# ? Function to check audio volume using ffmpeg
check_silence() {
  max_volume=$(ffmpeg -t 10 -i "$STREAM_URL" -af "volumedetect" -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5}')
  echo "Detected max volume: $max_volume"

  if [[ ! -z "$max_volume" ]]; then
    # Remove negative sign and decimal part
    volume_int=$(echo "$max_volume" | sed 's/-//' | cut -d'.' -f1)
    bar_length=$((20 - volume_int))
    [[ $bar_length -lt 0 ]] && bar_length=0
    [[ $bar_length -gt 20 ]] && bar_length=20

    # Choose color based on volume
    if (( bar_length < 7 )); then
      color="\e[31m"  # Red
    elif (( bar_length < 14 )); then
      color="\e[33m"  # Yellow
    else
      color="\e[32m"  # Green
    fi

    # Build and display volume bar
    bar=$(printf "%-${bar_length}s" | tr ' ' '#')
    empty=$(printf "%$((20 - bar_length))s")
    echo -e "Volume bar: ${color}[${bar}${empty}]\e[0m"
  fi
}

# ? Main loop
while true; do
  # Start VLC with buffer setting
  cvlc "$STREAM_URL" --intf dummy --network-caching=$BUFFER_SIZE &
  VLC_PID=$!

  while true; do
    check_silence

    if [[ -z "$max_volume" ]]; then
      echo -e "\e[31mVolume read error ? restarting stream\e[0m"
      kill $VLC_PID
      ((restart_count++))
      echo -e "\e[31mRestart count: $restart_count\e[0m"
      break
    fi

    if (( $(echo "$max_volume > -50.0" | bc -l) )); then
      echo "Sound is OK. Waiting before next check..."
    else
      echo -e "\e[31mSilence detected ? restarting stream\e[0m"
      kill $VLC_PID
      ((restart_count++))
      echo -e "\e[31mRestart count: $restart_count\e[0m"
      break
    fi

    sleep 20
  done
done
