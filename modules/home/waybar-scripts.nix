{ pkgs, ... }:

let
  # --- UPTIME SCRIPT ---
  wb-uptime = pkgs.writeShellApplication {
    name = "wb-uptime";
    runtimeInputs = [ pkgs.gawk ]; # Used for text processing and math on /proc/uptime
    text = ''
      awk '{
        d=int($1/86400);
        h=int(($1%86400)/3600);
        m=int(($1%3600)/60); 
        if(d>0) printf "%dd ",d; 
        if(h>0) printf "%dh ",h; 
        printf "%dm\n",m
      }' /proc/uptime
    '';
  };

  # --- VOLUME STEP SCRIPT ---
wb-vol-step = pkgs.writeShellApplication {
    name = "wb-vol-step";
    runtimeInputs = [ 
      pkgs.coreutils # For cat and echo
      pkgs.procps    # For pkill to refresh waybar
    ];
    text = ''
      STATE_FILE="/tmp/vol_step"
      # Default to 1 if the file doesn't exist
      curr=$(cat "$STATE_FILE" 2>/dev/null || echo 1)

      case "''${1:-}" in
        up)
          case "$curr" in
            1)  next=2 ;;
            2)  next=5 ;;
            5)  next=10 ;;
            10) next=10 ;; # Stay at 10
            *)  next=1 ;;
          esac
          echo "$next" > "$STATE_FILE"
          pkill -RTMIN+1 waybar || true
          ;;
        down)
          case "$curr" in
            10) next=5 ;;
            5)  next=2 ;;
            2)  next=1 ;;
            1)  next=1 ;; # Stay at 1
            *)  next=1 ;;
          esac
          echo "$next" > "$STATE_FILE"
          pkill -RTMIN+1 waybar || true
          ;;
        reset)
          echo 1 > "$STATE_FILE"
          pkill -RTMIN+1 waybar || true
          ;;
        get)
          cat "$STATE_FILE" 2>/dev/null || echo 1
          ;;
      esac
    '';
  };

  # --- SCREEN RECORDER TOOL ---
  wb-screen-record = pkgs.writeShellApplication {
    name = "wb-screen-record";
    runtimeInputs = [
      pkgs.wl-screenrec # The recording backend
      pkgs.hyprland     # To get monitor info via hyprctl
      pkgs.jq           # To parse hyprctl JSON output
      pkgs.libnotify    # To send 'Recording Saved' notifications
      pkgs.pulseaudio   # For pactl to identify audio sinks
      pkgs.procps       # For ps (process checking) and pkill
      pkgs.coreutils    # For date, cat, mkdir, sleep, etc.
      pkgs.ffmpeg       # To generate video thumbnails for notifications
    ];

    text = ''
      PID_FILE="/tmp/wl-screenrec.pid"
      START_TIME_FILE="/tmp/wl-screenrec-start"
      PATH_FILE="/tmp/wl-screenrec-path"
      VIDEO_DIR="$HOME/Videos/Recordings"

      mkdir -p "$VIDEO_DIR"

      get_status() {
          if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null; then
              start_time=$(cat "$START_TIME_FILE")
              current_time=$(date +%s)
              elapsed=$((current_time - start_time))
              
              if [ "$elapsed" -ge 3600 ]; then
                  timer=$(date -u -d "@$elapsed" +%H:%M:%S)
              else
                  timer=$(date -u -d "@$elapsed" +%M:%S)
              fi

              text="<span color='#ff3333'>●</span> $timer"
              echo "{\"text\": \"$text\", \"tooltip\": \"Recording active...\", \"class\": \"recording\", \"alt\": \"stop\"}"
          else
              rm -f "$PID_FILE"
              echo "{\"text\": \"\", \"tooltip\": \"Start Recording\", \"class\": \"idle\", \"alt\": \"record\"}"
          fi
      }

      toggle_recording() {
          if [ -f "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" > /dev/null; then
              PID=$(cat "$PID_FILE")
              FILENAME=$(cat "$PATH_FILE")
              THUMB="/tmp/rec_thumb.png"

              kill -SIGINT "$PID"
              while ps -p "$PID" > /dev/null; do sleep 0.2; done

              ffmpeg -y -i "$FILENAME" -ss 00:00:00.500 -vframes 1 "$THUMB" > /dev/null 2>&1
              notify-send -a "wb-screen-record" -i "$THUMB" "Recording Saved" "File: $(basename "$FILENAME")"
              
              rm -f "$PID_FILE" "$START_TIME_FILE" "$PATH_FILE"
              pkill -RTMIN+2 waybar || true
          else
              monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
              default_sink=$(pactl get-default-sink)
              audio_source="''${default_sink}.monitor"
              timestamp=$(date +%Y-%m-%d_%H-%M-%S)
              filename="$VIDEO_DIR/recording_''${timestamp}.mp4"
              
              wl-screenrec --max-fps 144 --audio --audio-device "$audio_source" --output "$monitor" -f "$filename" &
              
              echo $! > "$PID_FILE"
              date +%s > "$START_TIME_FILE"
              echo "$filename" > "$PATH_FILE"
              pkill -RTMIN+2 waybar || true
          fi
      }

      case "''${1:-}" in
          status) get_status ;;
          toggle) toggle_recording ;;
          *) echo "Usage: wb-screen-record {status|toggle}" ;;
      esac
    '';
  };

  # --- PLAYER STATUS ICON (Play/Pause) ---
  wb-player-status = pkgs.writeShellApplication {
    name = "wb-player-status";
    runtimeInputs = [ pkgs.playerctl pkgs.coreutils ];
    text = ''
      get_icon() {
          # Added -p io.bassi.Amberol,spotify,%any to prioritize Spotify
          status=$(playerctl -p io.bassi.Amberol,spotify,%any status 2>/dev/null || echo "Stopped")
          if [ "$status" = "Playing" ]; then echo "󰏤"; 
          elif [ "$status" = "Paused" ]; then echo "󰐊";
          else echo ""; fi
      }
      get_icon
      # Follow prioritized player changes
      playerctl -p io.bassi.Amberol,spotify,%any status --follow 2>/dev/null | while read -r _; do
          get_icon
      done
    '';
  };

  # --- PLAYER METADATA (Song - Artist) ---
  wb-player-metadata = pkgs.writeShellApplication {
    name = "wb-player-metadata";
    runtimeInputs = [ pkgs.playerctl pkgs.coreutils ];
    text = ''
      get_meta() {
          meta=$(playerctl -p io.bassi.Amberol,spotify,%any metadata --format '{{title}} - {{artist}}' 2>/dev/null || echo "")
          echo "$meta"
      }
      get_meta
      # Follow prioritized metadata changes
      playerctl -p io.bassi.Amberol,spotify,%any metadata --follow --format '{{title}}' 2>/dev/null | while read -r _; do
          get_meta
      done
    '';
  };
in
{
  home.packages = [ 
    wb-uptime 
    wb-vol-step 
    wb-screen-record
    wb-player-status
    wb-player-metadata
  ];
}