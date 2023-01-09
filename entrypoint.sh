#!/bin/sh -l

set -e  # if a command fails it stops the execution
set -u  # script fails if trying to access to an undefined variable

echo "[+] Action start"
DESTINATION_REPOSITORY_USERNAME="${1}"
DESTINATION_REPOSITORY_NAME="${2}"
DESTINATION_BRANCH="${3}"
USER_EMAIL="${4}"
USER_NAME="${5}"
GITHUB_SERVER="${6}"

# Verify that there (potentially) some access to the destination repository
# and set up git (with GIT_CMD variable) and GIT_CMD_REPOSITORY
if [ -n "${SSH_DEPLOY_KEY:=}" ]
then
	echo "[+] Using SSH_DEPLOY_KEY"

	mkdir --parents "$HOME/.ssh"
	DEPLOY_KEY_FILE="$HOME/.ssh/deploy_key"
	echo "${SSH_DEPLOY_KEY}" > "$DEPLOY_KEY_FILE"
	chmod 600 "$DEPLOY_KEY_FILE"

	SSH_KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"
	ssh-keyscan -H "$GITHUB_SERVER" > "$SSH_KNOWN_HOSTS_FILE"

	export GIT_SSH_COMMAND="ssh -i "$DEPLOY_KEY_FILE" -o UserKnownHostsFile=$SSH_KNOWN_HOSTS_FILE"

	GIT_CMD_REPOSITORY="git@$GITHUB_SERVER:$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git"

elif [ -n "${API_TOKEN_GITHUB:=}" ]
then
	echo "[+] Using API_TOKEN_GITHUB"
	GIT_CMD_REPOSITORY="https://$DESTINATION_REPOSITORY_USERNAME:$API_TOKEN_GITHUB@$GITHUB_SERVER/$DESTINATION_REPOSITORY_USERNAME/$DESTINATION_REPOSITORY_NAME.git"
else
	echo "::error::API_TOKEN_GITHUB and SSH_DEPLOY_KEY are empty. Please fill one (recommended the SSH_DEPLOY_KEY)"
	exit 1
fi

echo "[+] Isolate source repo"
SOURCE_DIRECTORY=$(mktemp -d)
cp -ra ./ $SOURCE_DIRECTORY

echo "[+] Set directory is safe"
git config --global --add safe.directory "$SOURCE_DIRECTORY"

echo "[+] Git version"
git --version

echo "[+] Git setup user"
# Setup git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

echo "[+] Cloning destination repository"
CLONE_DIR=$(mktemp -d)
git clone "$GIT_CMD_REPOSITORY" "$CLONE_DIR"

echo "[+] Replace .git*"
rm -rf $SOURCE_DIRECTORY/.git*
mv $CLONE_DIR/.git* $SOURCE_DIRECTORY/

echo "[+] Checkout out $DESTINATION_BRANCH"
cd $SOURCE_DIRECTORY
git checkout -b "$DESTINATION_BRANCH"

echo "[+] Files that will be pushed"
ls -la $SOURCE_DIRECTORY

echo "[+] Adding git commit"
git add .

echo "[+] git status:"
git status

echo "[+] git diff-index:"
COMMIT_MESSAGE="https://$GITHUB_SERVER/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
git diff-index --quiet HEAD || git commit --message "$COMMIT_MESSAGE"

echo "[+] git log:"
git log

echo "[+] Pushing git commit"
# --set-upstream: sets de branch when pushing to a branch that does not exist
git push -f "$GIT_CMD_REPOSITORY" "$DESTINATION_BRANCH"
