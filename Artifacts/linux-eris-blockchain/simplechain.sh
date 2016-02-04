#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# PURPOSE

# This script will setup a simple chain via the eris platform. It will make a
# chain with one validator node which will be run on the machine it is called
# from as well as two other accounts on the chain by default. All of these
# accounts will be given very simple and high level of permissions on the eris:
# db network.

# This script should **not** be used for production chains or even for complex
# pilots, but rather for only very simple chains used for testing or simple
# proofs of concept.

# For more information about what this script does please see the Eris docs @
#   * https://docs.erisindustries.com/tutorials/chainmaking/

# -----------------------------------------------------------------------------
# LICENSE

# The MIT License (MIT)
# Copyright (c) 2016-Present Eris Industries, Ltd.

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

# -----------------------------------------------------------------------------
# REQUIREMENTS

# Eris
# jq

# -----------------------------------------------------------------------------
# USAGE

# simplechain.sh [chainName] [chainDir]

# -----------------------------------------------------------------------------
# Set defaults

start=`pwd`
if [ -z "$1" ]
then
  chain_name=simplechain
else
  chain_name="$2"
fi
if [ -z "$2" ]
then
  chain_dir=$HOME/.eris/chains/simplechain
else
  chain_dir="$1"
fi
def_chain_dir=$HOME/.eris/chains/default
mkdir $chain_dir

# -----------------------------------------------------------------------------
# Sort keys

set -e
eris services start keys
addr1=$(eris keys gen | tr -d '\r')
addr2=$(eris keys gen | tr -d '\r')
addr3=$(eris keys gen | tr -d '\r')
pubky=$(eris keys pub "$addr1" | tr -d '\r')
privl=$(eris keys convert "$addr1" | tr -d '\r')

# -----------------------------------------------------------------------------
# Copy/make relevant files

echo "$privl" > $chain_dir/priv_validator.json
cp $def_chain_dir/config.toml $chain_dir/config.toml
cp $def_chain_dir/server_conf.toml $chain_dir/server_conf.toml
cp $def_chain_dir/genesis.json $chain_dir/genesis.json.bak

# -----------------------------------------------------------------------------
# Finalize the genesis.json

jq '.chain_id="simple_chain" | .accounts[0].address="'$addr1'" | .accounts[1].address="'$addr2'" | .accounts[2].address="'$addr3'" | del(.accounts[3, 4, 5, 6, 7, 8]) | .validators[0].pub_key[1]="'$pubky'" | .validators[0].unbond_to[0].address="'$addr1'"' $chain_dir/genesis.json.bak > $chain_dir/genesis.json

# -----------------------------------------------------------------------------
# Start the chain

eris chains new simplechain --dir $chain_dir

# -----------------------------------------------------------------------------
# Cleanup

rm $chain_dir/genesis.json.bak
cd $start
