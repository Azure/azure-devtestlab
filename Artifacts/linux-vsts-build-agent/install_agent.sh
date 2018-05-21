DOWNLOAD_URL="https://vstsagentpackage.azureedge.net/agent/2.131.0/vsts-agent-linux-x64-2.131.0.tar.gz"
INSTALL_PATH=/usr/local/vsts-agent-install
VSTS_ACCOUNT=""
VSTS_ACCOUNT_TOKEN=""
VSTS_AGENT_NAME="$HOSTNAME"
VSTS_AGENT_POOL=""
VSTS_AGENT_WORK_DIR=/usr/local/vsts-agent

LOGCMD='echo [AZDEVTST_VSTSAGENT] '

getopt --test > /dev/null
if [ $? -ne 4 ]; then
    $LOGCMD "ERROR: Could not find getopt, required for arg parsing"
    exit 1
fi
# Indicates all options require an argument after, none are flags
OPTIONS='a:t:n:p:w:'
PARSED_OPTIONS=`getopt --options=$OPTIONS --name "$0" -- "$@"`
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Option parsing failed"
    exit 2
fi
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
	$LOGCMD "ERROR: Coding error"
        exit 3
        ;;
    esac
done

$LOGCMD "INFO: VSTS configuration parameters..."
$LOGCMD "INFO: Account name - $VSTS_ACCOUNT"
$LOGCMD "INFO: Agent name - $VSTS_AGENT_NAME"
$LOGCMD "INFO: Agent pool name - $VSTS_AGENT_POOL"
$LOGCMD "INFO: Agent work directory - $VSTS_AGENT_WORK_DIR"

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
rm -f $DOWNLOAD_FILE

pushd $INSTALL_PATH > /dev/null
AGENT_VERSION=`./config.sh --version`
$LOGCMD "Found agent version $AGENT_VERSION"
$LOGCMD "Starting configuration..."
# As a workaround remove the check if running as sudo, see https://github.com/Microsoft/vsts-agent/issues/1481
sed -e '5,9d' "./config.sh" > "./config2.sh"
chmod +x "./config2.sh"

$LOGCMD "Installing git..."
apt-get install git -y

$LOGCMD "Installing VSTS dependencies..."
./bin/installdependencies.sh
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Could not install required dependencies"
    exit 1
fi

$LOGCMD "Creating work directory..."
mkdir $VSTS_AGENT_WORK_DIR

$LOGCMD "Configuring VSTS agent..."
./config2.sh --unattended  --url "https://$VSTS_ACCOUNT.visualstudio.com" --auth pat --token "$VSTS_ACCOUNT_TOKEN" --pool "$VSTS_AGENT_POOL" --agent "$VSTS_AGENT_NAME" --work "$VSTS_AGENT_WORK_DIR" --acceptTeeEula --replace
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Could not configue VSTS agent correctly"
    exit 1
fi

$LOGCMD "Installing VSTS agent service..."
./svc.sh install root
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Could not install VSTS agent"
    exit 1
fi

$LOGCMD "Launching VSTS agent service..."
./svc.sh start
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Could not start VSTS agent"
    exit 1
fi

$LOGCMD "VSTS agent service status..."
./svc.sh status
if [ $? -ne 0 ]; then
    $LOGCMD "ERROR: Could not get VSTS agent status"
    exit 1
fi

$LOGCMD "Done!"
popd
