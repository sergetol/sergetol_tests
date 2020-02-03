#!/bin/bash
set -evx

cd terraform/dev && terraform apply -auto-approve -var 'repo_branch=ansible-3'
