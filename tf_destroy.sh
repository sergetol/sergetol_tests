#!/bin/bash
set -evx

cd terraform/dev && terraform destroy -auto-approve
