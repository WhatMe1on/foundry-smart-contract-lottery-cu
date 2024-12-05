#!/bin/bash

# 设置默认的 commit message
DEFAULT_MSG="Default commit message"

# 使用传入的参数作为 commit message，否则使用默认值
COMMIT_MSG="${1:-$DEFAULT_MSG}"

# 执行 git 操作
git add . && \
git commit -m "$COMMIT_MSG" && \
git push
