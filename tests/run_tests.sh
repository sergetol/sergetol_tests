#!/bin/bash
set +e

RED="\033[0;31m"
GREEN="\033[0;32m"
DARKYELLOW="\033[0;33m"
CYAN="\033[0;36m"
LIGHTGRAY="\033[0;37m"

BRANCH="${TRAVIS_BRANCH:-master}"
BRANCH_TO_TEST="${BRANCH_TO_TEST:-master}"
# debug:
#BRANCH_TO_TEST=$BRANCH

if [ "$BRANCH" != "$BRANCH_TO_TEST" ]
then
  echo -e "${DARKYELLOW}Nothing to do for ${BRANCH} branch${LIGHTGRAY}"
  exit 0
fi

sudo apt-get update -qq > /dev/null
sudo apt-get upgrade -yqq > /dev/null
sudo apt-get install -yqq tree curl unzip grep > /dev/null

# Install python2 pip
#sudo apt-get install -yqq python-pip > /dev/null
#sudo -H python -m pip install -q --upgrade pip setuptools wheel
#echo "$(python --version) ($(which python))"
#python -m pip --version
#whereis pip
#PYTHON_COMMAND="python"

echo "Trying install default python3 ..."
sudo apt-get install -yqq python3 > /dev/null
echo "$(python3 --version) ($(which python3))"

PYTHON3_EXISTS="$(which python3)"
PYTHON3_MINOR_VERSION=0
if [ "$PYTHON3_EXISTS" != "" ]
then
  PYTHON3_MINOR_VERSION="$(python3 --version | grep -o -E '\.[[:digit:]]{1,2}\.' | grep -o -E '[[:digit:]]{1,2}')"
  PYTHON3_MINOR_VERSION="${PYTHON3_MINOR_VERSION:-0}"
fi
if [ "$PYTHON3_EXISTS" != "" ] && [ $PYTHON3_MINOR_VERSION -ge 6 ]
then
  echo "Installing pip3 ..."
  sudo apt-get install -yqq python3-pip > /dev/null
  python3 -m pip --version
  whereis pip3
  echo "Upgrading pip3 ..."
  sudo -H python3 -m pip install -q --upgrade pip setuptools wheel
  python3 -m pip --version
  whereis pip3
  PYTHON_COMMAND="python3"
else
  echo "Installing python3.6 ..."
  sudo add-apt-repository -y ppa:deadsnakes/ppa
  sudo apt-get update -qq > /dev/null
  sudo apt-get install -yqq python3.6 > /dev/null
  echo "$(python3.6 --version) ($(which python3.6))"
  echo "Installing pip3 ..."
  curl -sS https://bootstrap.pypa.io/get-pip.py | sudo -H python3.6
  python3.6 -m pip --version
  whereis pip3
  echo "Upgrading pip3 ..."
  sudo -H python3.6 -m pip install --upgrade pip setuptools wheel
  python3.6 -m pip --version
  whereis pip3
  PYTHON_COMMAND="python3.6"
fi

PACKER_VERSION=1.5.1
TERRAFORM_VERSION=0.12.20
TFLINT_VERSION=0.14.0
ANSIBLE_VERSION=2.9.4
ANSIBLE_LINT_VERSION=4.2.0

mkdir -p _tmp && cd _tmp

# Install packer
curl -OsS https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip && \
  unzip -oq packer_${PACKER_VERSION}_linux_amd64.zip && \
  rm -f packer_${PACKER_VERSION}_linux_amd64.zip && \
  sudo mv -f packer /usr/local/bin && \
  sudo chmod +x /usr/local/bin/packer

# Install terraform
curl -OsS https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
  unzip -oq terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
  rm -f terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
  sudo mv -f terraform /usr/local/bin && \
  sudo chmod +x /usr/local/bin/terraform

# Install tflint
curl -OLsS https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip && \
  unzip -oq tflint_linux_amd64.zip && \
  rm -r tflint_linux_amd64.zip && \
  sudo mv -f tflint /usr/local/bin && \
  sudo chmod +x /usr/local/bin/tflint

cd .. && rm -rf _tmp

# Install ansible and ansible-lint
sudo -H ${PYTHON_COMMAND} -m pip install -q ansible==${ANSIBLE_VERSION} ansible-lint==${ANSIBLE_LINT_VERSION}

echo -e "${LIGHTGRAY}"
echo -e "${DARKYELLOW}Version information:"
echo -e "${CYAN}$(packer version)"
echo -e "${CYAN}$(terraform version)"
echo -e "${CYAN}$(tflint --version)"
echo -e "${CYAN}$(ansible --version)"
echo -e "${CYAN}$(ansible-lint --version)"

echo -e "${LIGHTGRAY}"
echo -e "${DARKYELLOW}BRANCH: ${BRANCH}"

echo -e "${LIGHTGRAY}"
echo -e "${DARKYELLOW}$(pwd) directory tree:"
echo -e "${CYAN}$(tree -d -I *otus*)"

echo -e "${LIGHTGRAY}"
echo -e "${DARKYELLOW}Running tests ..."
echo -e "${LIGHTGRAY}"

test_result=""
test_exit_code=0
all_tests_count=0
passed_tests_count=0
failed_tests_count=0
skipped_tests_count=0

# packer validate
for f in $(cd packer && ls *.json)
do
  ((all_tests_count++))
  if [ "$f" = "app.json" ] || [ "$f" = "db.json" ]
  then
    echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}packer validate -var-file=packer/variables.json.example packer/${f}${LIGHTGRAY}"
    test_result="$(packer validate -var-file=packer/variables.json.example packer/${f})"
  else
    echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd packer && packer validate -var-file=variables.json.example ${f}${LIGHTGRAY}"
    test_result="$(cd packer && packer validate -var-file=variables.json.example ${f})"
  fi
  test_exit_code=$?

  if [ $test_exit_code -eq 0 ]
  then
    ((passed_tests_count++))
    echo -e "${GREEN}${test_result}${LIGHTGRAY}"
  else
    ((failed_tests_count++))
    echo -e "${RED}${test_result}${LIGHTGRAY}"
  fi
done

if [ "$f" = "" ]
then
  ((all_tests_count++))
  ((skipped_tests_count++))
  echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}No packer template found! Skip packer validate${LIGHTGRAY}"
fi
f=""

# terraform validate
((all_tests_count++))
echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd terraform && cp -f terraform.tfvars.example terraform.tfvars && terraform init -backend=false && terraform validate${LIGHTGRAY}"
test_result="$(cd terraform && cp -f terraform.tfvars.example terraform.tfvars && terraform init -backend=false && terraform validate)"
test_exit_code=$?
rm -f terraform/terraform.tfvars

if [ $test_exit_code -eq 0 ]
then
  ((passed_tests_count++))
  echo -e "${GREEN}${test_result}${LIGHTGRAY}"
else
  ((failed_tests_count++))
  echo -e "${RED}${test_result}${LIGHTGRAY}"
fi

((all_tests_count++))
echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd terraform/stage && cp -f terraform.tfvars.example terraform.tfvars && terraform init -backend=false && terraform validate${LIGHTGRAY}"
test_result="$(cd terraform/stage && cp -f terraform.tfvars.example terraform.tfvars && terraform init -backend=false && terraform validate)"
test_exit_code=$?
rm -f terraform/stage/terraform.tfvars

if [ $test_exit_code -eq 0 ]
then
  ((passed_tests_count++))
  echo -e "${GREEN}${test_result}${LIGHTGRAY}"
else
  ((failed_tests_count++))
  echo -e "${RED}${test_result}${LIGHTGRAY}"
fi

((all_tests_count++))
echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd terraform/prod && cp -f terraform.tfvars.example terraform.tfvars && terraform init -backend=false && terraform validate${LIGHTGRAY}"
test_result="$(cd terraform/prod && cp -f terraform.tfvars.example terraform.tfvars && terraform init -backend=false && terraform validate)"
test_exit_code=$?
rm -f terraform/prod/terraform.tfvars

if [ $test_exit_code -eq 0 ]
then
  ((passed_tests_count++))
  echo -e "${GREEN}${test_result}${LIGHTGRAY}"
else
  ((failed_tests_count++))
  echo -e "${RED}${test_result}${LIGHTGRAY}"
fi

# tflint
((all_tests_count++))
echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd terraform && tflint --var-file=terraform.tfvars.example --module${LIGHTGRAY}"
test_result="$(cd terraform && tflint --var-file=terraform.tfvars.example --module)"
test_exit_code=$?

if [ $test_exit_code -eq 0 ]
then
  ((passed_tests_count++))
  echo -e "${GREEN}${test_result}${LIGHTGRAY}"
else
  ((failed_tests_count++))
  echo -e "${RED}${test_result}${LIGHTGRAY}"
fi

((all_tests_count++))
echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd terraform/stage && tflint --var-file=terraform.tfvars.example --module${LIGHTGRAY}"
test_result="$(cd terraform/stage && tflint --var-file=terraform.tfvars.example --module)"
test_exit_code=$?

if [ $test_exit_code -eq 0 ]
then
  ((passed_tests_count++))
  echo -e "${GREEN}${test_result}${LIGHTGRAY}"
else
  ((failed_tests_count++))
  echo -e "${RED}${test_result}${LIGHTGRAY}"
fi

((all_tests_count++))
echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd terraform/prod && tflint --var-file=terraform.tfvars.example --module${LIGHTGRAY}"
test_result="$(cd terraform/prod && tflint --var-file=terraform.tfvars.example --module)"
test_exit_code=$?

if [ $test_exit_code -eq 0 ]
then
  ((passed_tests_count++))
  echo -e "${GREEN}${test_result}${LIGHTGRAY}"
else
  ((failed_tests_count++))
  echo -e "${RED}${test_result}${LIGHTGRAY}"
fi

# install external ansible roles
((all_tests_count++))
echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd ansible && ansible-galaxy install -r environments/stage/requirements.yml${LIGHTGRAY}"
test_result="$(cd ansible && ansible-galaxy install -r environments/stage/requirements.yml)"
test_exit_code=$?

if [ $test_exit_code -eq 0 ]
then
  ((passed_tests_count++))
  echo -e "${GREEN}${test_result}${LIGHTGRAY}"
else
  ((failed_tests_count++))
  echo -e "${RED}${test_result}${LIGHTGRAY}"
fi

# ansible-playbook --syntax-check
for f in $(cd ansible/playbooks && ls *.yml)
do
  ((all_tests_count++))
  echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook -i ansible/old/inventory ansible/playbooks/${f} --syntax-check${LIGHTGRAY}"
  test_result="$(ANSIBLE_ROLES_PATH=ansible/roles ansible-playbook -i ansible/old/inventory ansible/playbooks/${f} --syntax-check)"
  test_exit_code=$?

  if [ $test_exit_code -eq 0 ]
  then
    ((passed_tests_count++))
    echo -e "${GREEN}${test_result}${LIGHTGRAY}"
  else
    ((failed_tests_count++))
    echo -e "${RED}${test_result}${LIGHTGRAY}"
  fi
done

if [ "$f" = "" ]
then
  ((all_tests_count++))
  ((skipped_tests_count++))
  echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}No ansible playbooks found! Skip ansible-playbook --syntax-check${LIGHTGRAY}"
fi
f=""

# ansible-lint
for f in $(cd ansible/playbooks && ls *.yml)
do
  ((all_tests_count++))
  echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}cd ansible && ansible-lint playbooks/${f} --exclude=roles/jdauphant.nginx${LIGHTGRAY}"
  test_result="$(cd ansible && ansible-lint playbooks/${f} --exclude=roles/jdauphant.nginx)"
  test_exit_code=$?

  if [ $test_exit_code -eq 0 ]
  then
    ((passed_tests_count++))
    echo -e "${GREEN}${test_result}${LIGHTGRAY}"
  else
    ((failed_tests_count++))
    echo -e "${RED}${test_result}${LIGHTGRAY}"
  fi
done

if [ "$f" = "" ]
then
  ((all_tests_count++))
  ((skipped_tests_count++))
  echo -e "${DARKYELLOW}(Test ${all_tests_count}): ${CYAN}No ansible playbooks found! Skip ansible-lint${LIGHTGRAY}"
fi
f=""

echo -e "${LIGHTGRAY}"
echo -e "${DARKYELLOW}Test Summary (${all_tests_count}): ${GREEN}${passed_tests_count} successful${DARKYELLOW}, ${RED}${failed_tests_count} failed${DARKYELLOW}, ${CYAN}${skipped_tests_count} skipped${LIGHTGRAY}"

echo -e "${LIGHTGRAY}"
echo -e "${DARKYELLOW}... done (running tests)${LIGHTGRAY}"

if [ $failed_tests_count -gt 0 ]
then
  exit 1
fi

exit 0
