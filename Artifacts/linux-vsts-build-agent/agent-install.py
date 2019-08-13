#!/usr/bin/python3

from argparse import ArgumentParser
from socket import gethostname
from os import path, makedirs, environ
from sys import argv
from tempfile import TemporaryDirectory
from subprocess import run, PIPE, STDOUT
from requests import get
from json import loads

def parse_args(args):
    parser = ArgumentParser()
    parser.add_argument("-p", "--agent_path", required = True)
    parser.add_argument("-t", "--ado_pat", required = True)
    parser.add_argument("-a", "--ado_account", required = True)
    parser.add_argument("-l", "--ado_pool", required = True)
    parser.add_argument("-n", "--agent_name", required = False)
    result = parser.parse_args(args)
    if not result.agent_name:
        result.agent_name = gethostname()
    return result

def combine_command(command):
    return " ".join(command)

def failed(results):
    return results.returncode != 0

def execute_command_silent(command, cwd = None, env = None):
    results = run(command, stdout = PIPE, stderr = STDOUT, cwd = cwd, env = env)
    if failed(results):
        raise Exception(f"{combine_command(command)} failed. stdout={results.stdout} stderr={results.stderr}")
    return results

def execute_command(command, cwd = None, env = None):
    print (combine_command(command))
    return execute_command_silent(command, cwd = cwd, env = env)

def ensure_directory(dir):
    if not path.exists(dir):
        makedirs(dir)

def get_package_url(args):
    url = f"https://{args.ado_account}.visualstudio.com/_apis/distributedtask/packages/agent/linux-x64?$top=1&api-version=3.0"
    print(f"fetching {url} to determine agent package url")
    response = get(url, auth=("AzureDevTestLabs", args.ado_pat))
    as_json = loads(response.text)
    return as_json["value"][0]["downloadUrl"]

def download_and_extract_agent_package(args):
    with TemporaryDirectory() as temp_dir:
        execute_command([
            "wget",
            "--secure-protocol", "TLSv1_2",
            "-O", "agent.tgz",
            get_package_url(args)
        ], cwd = str(temp_dir))
        execute_command([
            "tar",
            "zxvf",
            f"{temp_dir}/agent.tgz"
        ], cwd = args.agent_path)

def install_dependencies(agent_path):
    execute_command([
        "sudo",
        "bin/installdependencies.sh"
    ], cwd = agent_path)

def configure_agent(args):
    d = dict(environ)
    d["AGENT_ALLOW_RUNASROOT"] = str("1")
    execute_command([
        "./config.sh",
        "--unattended",
        "--url", f"https://{args.ado_account}.visualstudio.com",
        "--auth", "pat",
        "--pool", args.ado_pool,
        "--agent", args.agent_name,
        "--work",  f"{args.agent_path}/_work",
        "--token", args.ado_pat
    ], cwd = args.agent_path, env = d)

def install_and_start(agent_path):
    execute_command([
        "sudo",
        "./svc.sh",
        "install"
    ], cwd = agent_path)
    execute_command([
        "sudo",
        "./svc.sh",
        "start"
    ], cwd = agent_path)

def main():
    args = parse_args(argv[1:])
    ensure_directory(args.agent_path)
    download_and_extract_agent_package(args)
    install_dependencies(args.agent_path)
    configure_agent(args)
    install_and_start(args.agent_path)
    return 0

if __name__ == "__main__":
    exit(main())
