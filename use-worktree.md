# git worktreeの利用

## ポイント

* gitは相対パス利用 : Git 2.48+の--relative-paths/worktree.useRelativePaths
    * ホストとDevContainerそれぞれでgit操作をするため
* WorkTreeは<repository root>/.worktrees/ 以下に作成
    * <repository root>/をDev Containerにマウントするため、よく見る同階層に配置する方式がとれない

ディレクトリ構成はこのようになる

```
<repository name>/
 ├─ .claude/
 ├─ .devcontainer/
 ├─ .git/
 ├─ src/
 └─ .worktrees/
     ├─ feature-example/
     └─ bugfix-example/
```

## 事前作業

worktree.useRelativePathsを有効化

```
git config worktree.useRelativePaths true

# useRelativePaths = true があるはず
cat .git/config
```

.worktrees/ を.gitignoreにいれておく。


## ワークツリーの作成

新規のブランチを切る場合

```
git worktree add -b feature/example .worktrees/feature-example origin/main
```

すでにあるブランチを使う場合

```
git worktree add .worktrees/feature-example feature/example
```


## Claude Codeの起動

作成したワークツリーまで移動した後でClaude Codeを立ち上げる。

```
cd .worktrees/feature-example
claude
```

## ワークツリーの削除

```
git worktree remove .worktrees/feature-example
```

