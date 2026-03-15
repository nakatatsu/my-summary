# AIにGitHub権限を与える方式

## さまざまな権限付与方式

AIにGitHubを操作させる方法としては、HITL（Human In The Loop）、プロキシ利用、GitHub App、PAT格納などの方式があり、それぞれ利便性やリスクが異なる。単独で他のすべてに勝る方式はないため、用途に応じて選択するとよい。

| モデル                  | 基本方式                                             | 漏洩時の権限の寿命          | 効率性                     | 流出リスク                   |
| ----------------------- | ---------------------------------------------------- | --------------------------- | -------------------------- | ---------------------------- |
| HITL(Human In The Loop) | AIがアクセスできない場所から人間がghなどで操作を実行 | （AIにPAT/tokenを渡さない） | 人手が常に必要             | ありえない                   |
| プロキシ利用            | PATを格納したプロキシに中継させる                    | （AIにPAT/tokenを渡さない） | 使えるツールが限定され不便 | ありえない                   |
| GitHub App              | GitHub Appが短命トークンを発行。それをAIが利用する   | 短命                        | 高い                       | ありえるが悪用リスクは限定的 |
| 直接トークン            | PATをAIに直接付与                                    | 長命                        | 高い                       | ありえる                     |

※ 流出リスクについて: 上記はあくまでAIによるPAT流出リスクについての評価である。オペミス等別の要因によって流出するケースは議論の外である。

### 使い分け

- 極めて高いセキュリティを求められており、わずかなリスクの可能性すら許容しがたい -> HITL
- PRスパム程度ならともかくPAT漏洩リスクの可能性は一切許容できない、あるいは諸事情でGitHub Appが使えない -> プロキシ
- 他の施策と合わせればインシデント発生時の被害を許容範囲内に抑えられる -> GitHub App
- 漏洩してもさして問題ない環境（実験用など）である -> PAT直渡し

## 利用方法

### HITL

手動で利用するのと同じ。

AIはコマンドを指示したり、テキストを作ったりする程度である。

## プロキシ利用

PAT/Tokenをプロキシに配置し、AIがアクセスできないようにする。AIはHTTP経由でGitHub APIを呼ぶだけである。

理屈は難しくなく、docker-composeでDevContainerを起動してサイドカーにNginxを使い

```
  gh-proxy:
    image: nginx:alpine
    volumes:
      - ./gh-proxy/default.conf.template:/etc/nginx/templates/default.conf.template:ro
    environment:
      GH_PAT: ${GITHUB_CLAUDECODE_KEY}
```

環境変数でPATをこのような設定を読み込ませるだけでも利用できる。なお、なるべくFine-grained personal access tokensを用い、強すぎる権限を付与しないこと。

```
server {
    listen 80;

    location / {
        proxy_pass https://api.github.com;
        proxy_set_header Host api.github.com;
        proxy_set_header Authorization "Bearer ${GH_PAT}";
        proxy_set_header User-Agent "gh-proxy";
        proxy_ssl_server_name on;
    }
}
```

### GitHub App

トークン生成用環境（サイドカーコンテナやAWS Lambdaなどを利用）を用意し、そこでGitHub Appの秘密鍵を使って短命トークンを発行する。
PATは使わない。AIエージェントは生成された短命トークンを利用してアクセスする。

1. GitHub Apps を登録
2. 取得した秘密鍵を保存し、トークン生成用環境で利用できるようにする。この時、AIエージェントが稼働する環境に決して秘密鍵を露出させないこと。トークン生成用環境にもAIエージェントを導入してはならない
3. トークン生成用環境でトークンを生成し、AIエージェントに渡す
4. 利用の都度AIエージェントはトークンを発行させ、これを利用する。Claude CodeならSKILLに入れておくと自己判断で実施してくれる。

トークンを発行させて利用するコマンドの例はこちら。

```
export GH_TOKEN=$(curl -fsS http://gh-token-sidecar/token | jq -r '.token')
```

### 直接トークン付与

環境変数を経由してPATをDevContainerに渡す。もっとも手間がかからず高効率、ただしAIがいつでもPATを流出させることができる。

こう書くとNGにしか読めないかもしれないが、漏洩リスクを許容できる環境なら手間が少なく良い手法である。
ただし付与する権限だけは絞っておくほうがよい。フル権限でリポジトリ制限なしの権限を与えたキーは決して渡すべきでない。

## 備考

- 上記いずれの方式を取ったとしても、最小権限の原則など他の方策も併用することが望ましい。短命トークンでも油断は禁物、管理者権限を与えていたらそこから別の永続型の権限を作られてしまう。
