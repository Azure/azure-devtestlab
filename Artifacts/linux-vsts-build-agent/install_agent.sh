# Script to install the linux VSTS build agent and register the machine with a
# specific pool

# Require arguments
# vsts_account name
# vsts_agent_working_dir

#  URL -> https://vstsagentpackage.azureedge.net/agent/2.131.0/vsts-agent-linux-x64-2.131.0.tar.gz

DOWNLOAD_URL="https://vstsagentpackage.azureedge.net/agent/2.131.0/vsts-agent-linux-x64-2.131.0.tar.gz"
INSTALL_PATH=/usr/share/vsts-agent-install
VSTS_ACCOUNT=""
VSTS_ACCOUNT_TOKEN=""
VSTS_AGENT_NAME="$HOSTNAME"
VSTS_AGENT_POOL=""
VSTS_AGENT_WORK_DIR=/vsts-agent

LOGCMD='echo [AZDEVTST_VSTSAGENT] '

getopt --test > /dev/null
if [ $? -ne 4 ]; then
    $LOGCMD "ERROR: Could not find getopt, required for arg parsing"
    exit 1
fi
# Indicates account, token and pool are required to have arguments, other arguments are just flags
OPTIONS='a:t:n:p:w:'
PARSED_OPTIONS=`getopt --options=$OPTIONS --name "$0" -- "$@"`
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Option parsing failed"
    exit 2
fi
$LOGCMD "Found arguments: $PARSED_OPTIONS"
if [[ ! $PARSED_OPTIONS =~ "-a" ]]; then
    $LOGCMD "ERROR: Missing VSTS account name (-a)"
    exit 2
fi
if [[ ! $PARSED_OPTIONS =~ "-t" ]]; then
    $LOGCMD "ERROR: Missing VSTS PAT (-t)"
    exit 2
fi
if [[ ! $PARSED_OPTIONS =~ "-p" ]]; then
    $LOGCMD "ERROR: Missing VSTS pool name for agent to join (-p)"
    exit 2
fi
eval set -- $PARSED_OPTIONS
while true; do
    case $1 in
    -a)
        VSTS_ACCOUNT="$2"
        shift 2
        ;;
    -t)
        VSTS_ACCOUNT_TOKEN="$2"
        shift 2
        ;;
    -p)
        VSTS_AGENT_POOL="$2"
        shift 2
        ;;
    -n)
        VSTS_AGENT_NAME="$VSTS_AGENT_NAME$2"
        shift 2
        ;;
    -w)
        VSTS_AGENT_WORK_DIR="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        exit 3
        ;;
    esac

DOWNLOAD_FILE=`mktemp -t vsts_agent_XXXXXX.tar.gz`
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Could not create temporary download destination"
    exit 1
fi
$LOGCMD "Tempfile at $DOWNLOAD_FILE"

wget -nv -t 10 -O $DOWNLOAD_FILE -- $DOWNLOAD_URL
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Could not download VSTS linux agent"
    rm -f $DOWNLOAD_FILE
    exit 1
fi

if [ -d $INSTALL_PATH ]; then
    rm -rf $INSTALL_PATH
fi
mkdir -p $INSTALL_PATH
tar zxf $DOWNLOAD_FILE -C $INSTALL_PATH
$LOGCMD "Extraction complete"

pushd $INSTALL_PATH
AGENT_VERSION=`./config.sh --version`
$LOGCMD "Found agent version $AGENT_VERSION"
$LOGCMD "Starting configuration..."

popd
