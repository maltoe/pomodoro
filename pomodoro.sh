#!/usr/bin/env bash

#
# pomodoro
#
# A simple pomodoro timer with libnotify-based notifications.
#
# Configurable through command line switches and config file.
#
# Comes with tomato icon from Twitter Emoji library:
# https://github.com/twitter/twemoji
#
# Thanks to Francesco Cirillo from where I borrowed the introduction messages.
# https://francescocirillo.com/pages/pomodoro-technique
#
# See for help
#
# $ pomodoro -h
#

TRUE=0
FALSE=1

config_dir=$HOME/.config/pomodoro
config_file=$config_dir/rc
icon_file=$config_dir/1f345.png

normal=$(tput sgr0)
bold=$(tput bold)
red=$(tput setaf 1)

##
# write_config <notifier> <repeat> <pattern>
#
write_config() {
  mkdir -p $config_dir

  cat >$config_file <<EndOfConfig
# Any of echo,libnotify
notifier=$1

# Set to 1 to have pomodoro repeat by default
repeat=$2

# See help (pomodoro -h)
pattern=$3
EndOfConfig

  image_tag=$(cat $0 | grep -an "__IMAGE__" | tail -n1 | cut -d ':' -f 1)
  tail -n+$((image_tag + 1)) $0 > $icon_file
}

##
# usage <pattern_default> <notifier_default>
#
usage() {
  cat <<EndOfUsage
Usage: $0 [OPTION]

    Runs a simple pomodoro timer with notifications.

    -r             Repeat. Restart pomodoro timer after last (break) period.

    -p <pattern>   Set period sequence to pattern.

                   The pattern needs to be a colon-separated list of period descriptions.
                   A period description is a single character (any of r[eminder], p[omodoro],
                   b[reak], or f[inish]) followed by a comma and then followed by an integral
                   number of seconds of period duration.

                   The default pattern is (defined in $config_file):

                   $1

    -n <notifier>  Comma separated list of notifiers to use. Defaults to: $notifier_default
    -d             Dry-run. Don't actually sleep for seconds given in pattern, but 1 second.
    -h             Print this help.

EndOfUsage

  exit 1
}

##
# format_time <seconds>
#
format_time() {
  seconds=$1
  if [ $seconds -lt 60 ]; then
    echo "$seconds seconds"
  elif [ $seconds -eq 60 ]; then
    echo "1 minute"
  else
    echo "$((seconds / 60)) minutes"
  fi
}

##
# say <notifier> <summary> <body>
#
say() {
  notifier=$1
  shift

  if notifier_selected? $notifier libnotify; then
    do_say_with_libnotify "$@"
  fi

  if echo $notifier | grep -q echo; then
    do_say_with_echo "$@"
  fi
}

##
# do_say_with_libnotify <summary> <body> [show duration]
#
do_say_with_libnotify() {
  if [ $# -eq 3 ]; then
    notify-send -i $icon_file -t $3 "$1" "$2"
  else
    notify-send -i $icon_file "$1" "$2"
  fi
}

do_say_with_echo() {
  echo -e "${bold}-> $1${normal}\n$2\n"
}

check_notify_send() {
  if ! command -v notify-send >/dev/null; then
    echo "ERROR: libnotify notifier selected, but notify-send not found"
    echo
    echo "Please install libnotify tools (libnotify-bin package on Debian systems)."
    exit 1
  fi
}

##
# has_notifier <notifier-list> <notifier>
#
notifier_selected?() {
  if echo $1 | grep -q $2; then
    return $TRUE;
  else
    return $FALSE;
  fi
}

##
# sleep_with_progress <notifier> <seconds>
#
sleep_with_progress() {
  notifier=$1
  remaining=$2
  show_remaining=$FALSE

  if notifier_selected? $notifier "echo"; then
    show_remaining=$TRUE
  fi

  if [ $remaining -lt 30 ]; then
    show_remaining=$FALSE
  fi

  while [ $remaining -gt 0 ]; do
    if [ $show_remaining -eq $TRUE ]; then
      echo -ne "\rTime remaining: ${bold}${red}$(format_time $remaining)${normal}               "
    fi

    sleep 1
    remaining=$((remaining - 1))
  done

  if [ $show_remaining -eq $TRUE ]; then
    echo -e "\r\n"
  fi
}

##
# run_timer <notifier> <dry-run> <pattern>
#
run_timer() {
  # Please note that the missing quotes are intended here.
  do_run_timer $1 $2 $(echo $3 | tr ':' ' ')
}

do_run_timer() {
  notifier=$1
  shift
  dry_run=$1
  shift

  while [ ! -z "$1" ]; do
    period=$(echo $1 | cut -d ',' -f 1)
    duration=$(echo $1 | cut -d ',' -f 2)

    case "$period" in
      i0)
        if notifier_selected? $notifier libnotify; then
          do_say_with_libnotify "Hey there!" "This little introduction will help you get started with the Pomodoro Technique." 9500
        fi
        if notifier_selected? $notifier "echo"; then
          do_say_with_echo "Welcome!" "This little introduction will help you get started with the ${red}Pomodoro Technique${normal}.\nIf you want to revisit this later, call pomodoro with the -i switch."
        fi
        ;;
      i1)
        say $notifier "Please follow along" "The fundamentals of the Pomodoro Technique are simple yet incredibly effective. A full cycle will take about 2 hours of time." 6500
        ;;
      i2)
        say $notifier "Choose a task you'd like to get done" "Something big, something small, something you've been putting off for a million years: it doesn't matter.\nWhat matters is that it's something that deserves your full, undivided attention.\nPlease prepare your work environment for a distraction-less experience. You have $(format_time $duration)." 15000
        ;;
      i3)
        say $notifier "The Pomodoro timer will be set for 25 minutes" "Make a small oath to yourself: I will spend 25 minutes on this task and I will not interrupt myself.\nYou can do it! After all, it's just 25 minutes." 10000
        ;;
      i4)
        say $notifier "Work on the task until the Pomodoro rings" "Immerse yourself in the task for the next 25 minutes.\nIf you suddenly realize you have something else you need to do, write the task down on a sheet of paper." 10000
        ;;
      i5)
        say $notifier "Congratulations! You have just spent an entire, interruption-less Pomodoro on a task" "Please put a checkmark on a paper."
        ;;
      i6)
        say $notifier "Take a short break!" "Breathe, meditate, grab a cup of coffee, go for a short walk or do something else relaxing (i.e., not work-related).\nYour brain will thank you later. Be back in $(format_time $duration)." 8000
        ;;
      i7)
        say $notifier "Ready again?" "We will now repeat this another three times."
        ;;
      i8)
        say $notifier "Pomodoro cycle complete!" "Final checkmark. Since you have completed four pomodoros, you should now take a longer break. 20 minutes is good.\nYour brain will use this time to assimilate new information and rest before the next round of Pomodoros." 10000
        ;;
      r)
        say $notifier "Pomodoro incoming" "Next pomodoro will begin in $(format_time $duration)."
        ;;
      p)
        say $notifier "Pomodoro begins now" "Please focus for $(format_time $duration)."
        ;;
      b)
        say $notifier "End of pomodoro" "Please take a $(format_time $duration) break."
        ;;
      f)
        say $notifier "End of pomodoro cycle" "Please stand up and take a $(format_time $duration) break."
        ;;
    esac

    if [ $dry_run -eq $TRUE ]; then
      echo "dry-run: would sleep for $duration seconds"
      echo
      sleep 1
    else
      sleep_with_progress $notifier $duration
    fi

    shift 1
  done
}

#### MAIN ####

default_pattern=r,60:p,1500:b,180:r,15:p,1500:b,180:r,15:p,1500:b,180:r,15:p,1500:f,1200
intro_pattern=i0,10:i1,7:i2,60:i3,11:i4,11:p,1500:i5,6:i6,285:i7,15:p,1500:b,285:r,15:p,1500:b,285:r,15:p,1500:i8,11:f,1200

naked_launch=$TRUE
first_use=$FALSE
dry_run=$FALSE
intro=$FALSE

notifier=echo,libnotify
repeat=$FALSE
pattern=$default_pattern

if [ -d $config_dir ]; then
  source $config_file
else
  first_use=$TRUE
fi

while getopts ":drip:n:" o; do
  case "${o}" in
    d)
      naked_launch=$FALSE
      dry_run=$TRUE
      ;;
    r)
      naked_launch=$FALSE
      repeat=$TRUE
      ;;
    i)
      # Hidden flag to enable first start introduction.
      intro=$TRUE
      ;;
    p)
      naked_launch=$FALSE
      pattern=${OPTARG}
      ;;
    n)
      naked_launch=$FALSE
      notifier=${OPTARG}
      ;;
    *)
      # Source config file again in case other options were present.
      source $config_file
      usage $pattern
      ;;
  esac
done

if notifier_selected? $notifier libnotify; then
  check_notify_send
fi

if [ $first_use -eq $TRUE ]; then
  # Smart config: If user gave options at first start, write those to config.
  write_config $notifier $repeat $pattern

  if [ $naked_launch -eq $TRUE ]; then
    # On first use, but only if no options given, show tour.
    intro=$TRUE
  fi
fi

while true; do
  if [ $intro -eq $TRUE ]; then
    run_timer $notifier $dry_run $intro_pattern
    intro=$TRUE
  else
    run_timer $notifier $dry_run $pattern
  fi

  if [ $repeat -eq $FALSE ]; then
    if notifier_selected? $notifier "echo"; then
      read -p "Would you like to restart the cycle now (y/n)? " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
      else
        echo
      fi
    else
      exit 0
    fi
  fi

  say $notifier "Restarting Pomodoro cycle..." ""
done

__IMAGE__
âPNG

   IHDR   H   H   b3Cu   üPLTE   ›.D›.D›.D›.Dw≤U›.D›.D›.D›.D›.D›.D›.D›.Dw≤U›.D›.D›.D›.Dw≤Uw≤Uw≤Uw≤Uw≤Uw≤Uw≤Uw≤Uw≤Uw≤Uw≤U–?FôÜOw≤U FGw≤Uw≤U›.D GGóâP◊6EÑ¢S™pMƒOHëëQ–?F∑`JäôR∞hKΩWIùÅO§xNw≤U}™TrAF∆   $tRNS <Êá W˚ˆÔŒ€¿˛ØpúWØÊÔ¿ á€˛˚Œ<¿ÔpÊˆú)dJ  ]IDATx^úœA
É0Ö·n≤ÿƒg2:mèºˇŸJ§T,4˛´Y}ºπZ¬ÑK›p»âúRK/≠åÓ®Ãíz!ì8~1âLËá‡2Y?ØLôΩ¡ìÃ˚{Ö$.Aê&≠vj&Y∏π≤%±¸≠¥M˚:é–`JÆkë“Ú ¢AjkÊ•˜5TZ‚ã¥#∆}a/îxöÑU{†·˛⁄¯£Ì˘ﬁÌ◊€éõ0Ä·,;émqxÜ†	ªÏ˚?[ì≥&⁄ÒM•˛7æ˚4âÑ˘Nø¯∂T[ ®Í-P_€\ÌugvI#`Æπ˛5‘•¨rá Bê4ñVÎ`S¬æÖRd~_FØ~+Y≥Iç£w3pÎc}-Ëºî‹Å‰	üÍÅ‘˜÷ëÕáÜfx5¯â¬É–in„Â≥Öµˆkº∏£Ø«ÏdÑ6Nﬂ›◊e \ÅÎcÑÄÑP~(Õ€È`_íØP	Å™Ît’ætzÅòÖP√<Y˚ô'§!XÉ«~lÖ–R+§ÅX6C®È Åúú†ÑïÙ‘  B“Ae(s–9d§b@âÉN1 Â àëç¡?˝á¨ÉT¨d“21†“Ai®pêå≤k≈¯˚Î	*ÈP:AåÏ>AÙg3î+àÍ@+îBà6RŒüPFpî˜1Jy0Ñ§†|d!‰*(BËÁoÓÃüE“¸"H%˜†üH6Á>Ñ7ø˜E‡NÀNÔØYÜoŸÊÕq≤√Î:S«å-C˜~,;†D)y¬ÿ˘˚≠')!Kµ°sÊ¬XjµpB%&e<–|ÜLl”?ló    IENDÆB`Ç
