#!/bin/sh

# Generate descriptor file for CANPAN/CANPAN3 modules.
# Use this script to avoid duplication and reduce maintenance.

TZ= datestring=`date +%Y%m%d%H%M`

moduleName=CANPAN
LEDs=32
switches=32

while getopts 'p:v:' opt; do
  case "$opt" in
    v)
      ver=$OPTARG
      ;;
    p)
      processor=$OPTARG
      case $OPTARG in
      23 ) # PIC18F27Q83
        processorSeries=Q
        ;;
      esac
      ;;
    *)
      echo "Usage: $0 [-p processor] -v <version>"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

if [ -z "$ver" ]
then
  echo "Version not set."
  echo "Usage: $0 [-p processor] -v <version>"
  exit 1
fi

# Capabilities per version
case $ver in
  1Y)
    ;;
  4C)
    ;;
  5a)
    moduleName="CANPAN3"
    ;;
  *)
    echo "$0: Unknown version '$ver'"
    exit 1
    ;;
esac

function commaIf()
{
  if [ "$@" ]
  then
    echo ","
  else
    echo ""
  fi
}

cat <<EOF
{
  "generated":"Generated by $0 ${processor:+-p $processor }-v $ver",
  "timestamp": "$datestring",
  "moduleName":"$moduleName",
  "nodeVariables": [
    {
      "type": "NodeVariableSelect",
      "nodeVariableIndex": 1,
      "displayTitle": "Startup Actions",
      "options": [
EOF
case "$ver" in
1Y)
  # This behaviour is described in the Knowledgebase page for CANPAN firmware but not in the comments in the assembler file.
  cat << EOF
        {"label": "0 - Send all current taught event states", "value": 0},
        {"label": "1 - Do nothing", "value": 1},
        {"label": "2 - Set all taught states to ON", "value": 2}
EOF
;;
4C)
  # This behaviour is described in the Knowledgebase page for CANPAN firmware but not in the comments in the assembler file.
  cat << EOF
        {"label": "0 - Send all current taught event states", "value": 0},
        {"label": "1 - Do nothing", "value": 1},
        {"label": "2 - Set all taught states to according to switches", "value": 2},
        {"label": "3 - Set all taught states to OFF", "value": 3}
EOF
;;
5a)
  # Described by Ian Hogg
  cat <<EOF
        {"label": "0 - Restore switch states", "value": 0},
        {"label": "1 - Do nothing", "value": 1},
        {"label": "2 - Restore switch states and LED states", "value": 2},
        {"label": "3 - Restore LED states", "value": 3}
EOF
;;
esac
cat <<EOF
      ]
    }$( commaIf "$ver" = "5a" )
EOF
if [ "$ver" = "5a" ]
then
cat <<EOF
    {
      "displayTitle": "Startup Event Delay",
      "type": "NodeVariableNumber",
      "nodeVariableIndex": 67,
      "displayUnits": "seconds"
    },
    {
      "displayTitle": "LED Flash rate",
      "type": "NodeVariableSlider",
      "nodeVariableIndex": 2,
      "displayUnits": "ms",
      "displayScale": 16.13
    },
    {
      "displayTitle": "LED Brightness",
      "type": "NodeVariableGroup",
      "groupItems": [
EOF
  for (( led=1 ; $led <= $LEDs ; ++led ))
  do
cat <<EOF
        {
          "displayTitle": "LED $led",
          "type": "NodeVariableSlider",
          "nodeVariableIndex": $((2+$led)),
          "max": 31
        }$( commaIf $led != $LEDs )
EOF
  done
cat <<EOF
      ]
    },
    {
      "displayTitle": "Switch Pairing",
      "type": "NodeVariableGroup",
      "groupItems": [
EOF
  for (( sw=1 ; $sw <= $switches ; sw+=2 ))
  do
cat <<EOF
        {
          "displayTitle": "Switches $sw & $(($sw + 1))",
          "type": "NodeVariableBitSingle",
          "nodeVariableIndex": $((2+$LEDs+$sw)),
          "bit": 0
        }$( commaIf $(($sw + 1)) -lt $switches )
EOF
  done
cat <<EOF
      ]
    }
EOF
fi
cat <<EOF
  ],
  "eventVariables": [
EOF
if [ $ver != "5a" ]
then
cat <<EOF
    {
      "displayTitle": "Event Type",
      "type": "EventVariableSelect",
      "eventVariableIndex": 1,
      "options": [
        { "value": 0, "label": "Consumed Event" },
        { "value": 1, "label": "Produced Event" },
        { "value": 2, "label": "Start of Day" },
        { "value": 3, "label": "Self SoD" }
      ]
    },
EOF
else
cat <<EOF
    {
      "displayTitle": "Start of Day",
      "type": "EventVariableBitSingle",
      "eventVariableIndex": 1,
      "bit": 1
    },
EOF
fi
cat <<EOF
    {
      "displayTitle": "Produced Event",
      "type": "EventVariableGroup",
EOF
if [ $ver != "5a" ]
then
cat <<EOF
      "visibilityLogic": {
        "ev": 1,
        "equals": 1
      },
EOF
fi
cat <<EOF
      "groupItems": [
        {
          "displayTitle": "Switch",
          "type": "EventVariableSelect",
          "eventVariableIndex": 2,
          "options": [
            {"label": "None", "value": 0},
EOF
for (( sw=1 ; $sw <= $switches ; ++sw ))
do
  cat <<EOF
            {"label": "Switch $sw", "value": $sw}$( commaIf $sw -lt $switches -o $ver = "5a" )
EOF
done
if [ $ver = "5a" ]
then
  cat <<EOF
            {"label": "Start up event", "value": $(($switches + 1))}
EOF
fi
cat <<EOF
          ]
        },
        {
          "displayTitle": "Mode",
          "type": "EventVariableSelect",
          "eventVariableIndex": 3,
          "bitMask": 15,
          "options": [
            { "value": 0, "label": "None" },
            { "value": 1, "label": "ON/OFF" },
            { "value": 3, "label": "OFF/ON (inverted)" },
            { "value": 4, "label": "ON only" },
            { "value": 6, "label": "OFF only" },
            { "value": 8, "label": "Push ON/Push OFF" }
          ],
          "visibilityLogic": { "JLL": { "and" : [
            { ">" : [ {"EV" : 2 }, 0 ]},
            { "<" : [ {"EV" : 2 }, 32 ]}
          ]}}
        }$( commaIf $ver != "5a" )
EOF
if [ $ver != "5a" ]
then
cat <<EOF
        {
          "displayTitle": "Set LEDs",
          "type": "EventVariableBitSingle",
          "eventVariableIndex": 3,
          "bit": 4
        },
        {
          "displayTitle": "Send Short Event",
          "displaySubTitle": "Set this when teaching a produced short events",
          "type": "EventVariableBitSingle",
          "eventVariableIndex": 3,
          "bit": 5
        }
EOF
fi
cat <<EOF
      ]
    },
EOF
if [ $ver != "5a" ]
then
cat <<EOF
    {
      "displayTitle": "Produced Self SoD Event",
      "type": "EventVariableGroup",
      "visibilityLogic": {
        "ev": 1,
        "equals": 3
      },
      "groupItems": [
        {
          "displayTitle": "Switch",
          "type": "EventVariableSelect",
          "eventVariableIndex": 2,
          "options": [
            {"label": "None", "value": 0},
EOF
for (( sw=1 ; $sw <= $switches ; ++sw ))
do
  cat <<EOF
            {"label": "Switch $sw", "value": $sw}$( commaIf $sw -lt $switches )
EOF
done
cat <<EOF
          ]
        },
        {
          "displayTitle": "Mode",
          "type": "EventVariableSelect",
          "eventVariableIndex": 3,
          "bitMask": 15,
          "options": [
            { "value": 0, "label": "None" },
            { "value": 1, "label": "ON/OFF" },
            { "value": 3, "label": "OFF/ON (inverted)" },
            { "value": 4, "label": "ON only" },
            { "value": 6, "label": "OFF only" },
            { "value": 8, "label": "Push ON/Push OFF" }
          ],
          "visibilityLogic": { "JLL": { "or" : [
            { ">" : [ {"EV" : 2 }, 0 ]},
            { "<" : [ {"EV" : 2 }, 32 ]}
          ]}}
        },
        {
          "displayTitle": "Send Short Event",
          "displaySubTitle": "Set this when teaching a produced short events",
          "type": "EventVariableBitSingle",
          "eventVariableIndex": 3,
          "bit": 5
        }
      ]
    },
EOF
fi
cat <<EOF
    {
      "displayTitle": "LEDs",
      "type": "EventVariableGroup",
EOF
if [ $ver != "5a" ]
then
cat <<EOF
      "visibilityLogic": {
        "evBit": { "index": 3, "bit": 4 },
        "equals": 1
      },
EOF
fi
cat <<EOF
      "groupItems": [
        {
          "displayTitle": "LED Action",
          "type": "EventVariableSelect",
          "eventVariableIndex": 13,
          "options": [
            { "value":   0, "label": "Undefined (0)" },
            { "value": 255, "label": "Normal" },
            { "value": 254, "label": "ON Only" },
            { "value": 253, "label": "OFF Only" },
            { "value": 248, "label": "Flash" }
          ]
        },
EOF
for (( ch=1 ; $ch <= $LEDs ; ++ch))
do
  cat <<EOF
        {
          "displayTitle": "LED $ch",
          "type": "EventVariableGroup",
          "groupItems": [
            {
              "displayTitle": "Active",
              "type": "EventVariableBitSingle",
              "eventVariableIndex": $((5+($ch-1)/8)),
              "bit": $((($ch-1)%8))
            },
            {
              "displayTitle": "Invert",
              "type": "EventVariableBitSingle",
              "eventVariableIndex": $((9+($ch-1)/8)),
              "bit": $((($ch-1)%8)),
              "visibilityLogic": { "JLL": { "==" : [ { "EVbit": [ $((5+($ch-1)/8)), $((($ch-1)%8)) ]}, true ]}}
            }
          ]
        }$( commaIf $ch != $LEDs)
EOF
done
cat <<EOF
      ]
    }$( commaIf $ver != "5a" )
EOF
if [ $ver != "5a" ]
then
cat <<EOF
    {
      "displayTitle": "Consumed Event",
      "type": "EventVariableGroup",
      "visibilityLogic": {
        "ev": 1,
        "equals": 0
      },
      "groupItems": [
        {
          "displayTitle": "LED Action",
          "type": "EventVariableSelect",
          "eventVariableIndex": 13,
          "options": [
            { "value":   0, "label": "Undefined (0)" },
            { "value": 255, "label": "Normal" },
            { "value": 254, "label": "ON Only" },
            { "value": 253, "label": "OFF Only" },
            { "value": 248, "label": "Flash" }
          ]
        },
EOF
for (( ch=1 ; $ch <= $LEDs ; ++ch ))
do
  cat <<EOF
        {
          "displayTitle": "LED $ch",
          "type": "EventVariableGroup",
          "groupItems": [
            {
              "displayTitle": "Active",
              "type": "EventVariableBitSingle",
              "eventVariableIndex": $((5+($ch-1)/8)),
              "bit": $((($ch-1)%8))
            },
            {
              "displayTitle": "Invert",
              "type": "EventVariableBitSingle",
              "eventVariableIndex": $((9+($ch-1)/8)),
              "bit": $((($ch-1)%8)),
              "visibilityLogic": { "JLL": { "==" : [ { "EVbit": [ $((5+($ch-1)/8)), $((($ch-1)%8)) ]}, true ]}}
            }
          ]
        }$( commaIf $ch != $LEDs)
EOF
done
cat <<EOF
      ]
    }
EOF
fi
cat <<EOF
  ]  
}
EOF