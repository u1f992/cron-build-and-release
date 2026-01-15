# cron-build-and-release

GitHub Actionsの再発明。`cron`で定期的にGitHubリポジトリを監視し、変更があればビルドしてリリースを作成します。

```
$ docker build \
    --build-arg CRON_SCHEDULE="*/10 * * * *" \
    --build-arg REPO_NAME="owner/repo" \
    --build-arg BUILD_COMMAND="pnpm install && pnpm build" \
    --build-arg RELEASE_ASSET="output.pdf" \
    -t cron-build-and-release .

$ docker run -it cron-build-and-release

# コンテナ内で
#   $ gh auth login
#   $ cron -f
```

## GitHub認証とトークン

コンテナにはGitHub認証が必要です。環境に応じて適切な方法を選択してください。

### 同一マシン・プライベートサーバーの場合

ホストの`gh auth`トークンを転送できます。

```
gh auth token | docker exec -i <container> gh auth login --with-token
```

### 共有マシンで自分のリポジトリの場合

Fine-grained Personal Access Token（PAT）を発行してください。

- Repository access: 対象リポジトリのみ選択
- Permissions: Contents (Read and write)

### 共有マシンで他者のリポジトリの場合

Fine-grained PATは自分が管理権限を持つリポジトリにしか発行できないため、Classic Personal Access Tokenを使用します。

- スコープ: `repo`, `read:org`

### トークンの転送

シェル履歴にトークンが残らないよう注意してください。

```
# 標準入力から入力（表示されない）
read -s TOKEN && echo "$TOKEN" | docker exec -i <container> gh auth login --with-token

# ファイルから転送
cat /path/to/token-file | docker exec -i <container> gh auth login --with-token
```

## run-in-devcontainer.sh／docker-bootstrap.sh

devcontainer環境でビルドを実行するためのヘルパースクリプト。

```
/run-in-devcontainer.sh <workspace-folder> <command>

BUILD_COMMAND="/run-in-devcontainer.sh . 'pnpm install && pnpm build'"
```

Docker in Dockerを使用するため`docker run`に`--privileged`が必要です。`docker-bootstrap.sh`を使用すると、Dockerデーモンを開始してから`cron`を実行できます。

```
$ docker run -it --privileged cron-build-and-release

# コンテナ内で
#   $ /docker-bootstrap.sh cron -f
```
