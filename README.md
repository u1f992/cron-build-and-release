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

- コンテナ内で`gh auth login`を実行してGitHubにログインする必要があります
  - ヒント：ホストのGitHubトークンをパイプで渡して認証する　`gh auth token | docker exec -i <container> gh auth login --with-token`

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
