#!/bin/bash

echo "Starting agent."
eval `ssh-agent -s`

echo "Current SSH_AUTH_SOCK:"
echo $SSH_AUTH_SOCK

echo "Installing key."
cp priv/ssh/evaluation /tmp/evaluation

echo "Changing permission on keys."
chmod 400 /tmp/evaluation

echo "Passphrase is set."
echo $EVALUATION_PASSPHRASE

echo "Adding key to agent."
( cd priv ; ./add_key.sh )

echo "Now SSH_AUTH_SOCK:"
echo $SSH_AUTH_SOCK

echo "After adding key, agent now contains the following"
ssh-add -l

GIT_SSH=ssh/wrapper
echo -n "Using the following wrapper: "
echo -n $GIT_SSH
echo

echo "Authentication socket."
echo $SSH_AUTH_SOCK

echo "Configuring git."
git config --global user.email "christopher.meiklejohn+lasp-lang-evaluator@gmail.com"
git config --global user.name "Lasp Language Evaluation Bot"

echo "Checking in results."
( cd priv/evaluation ; git add . )
( cd priv/evaluation ; git commit -m 'Adding evaluation data.' )
( cd priv/evaluation ; git status )

# Retries has to be at least more than the allowed concurrency in the
# system.
RETRIES=10000
R=0
(cd priv/evaluation ; GIT_SSH=../$GIT_SSH git push -u origin)

while [ $R -lt $RETRIES -a $? -ne 0 ]
do
  sleep 1
  R=$[$R+1]
  (cd priv/evaluation ; GIT_SSH=../$GIT_SSH git pull --rebase && GIT_SSH=../$GIT_SSH git push -u origin)
done

