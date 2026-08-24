# 関数シグネチャの型アノテーション規約 ルール本体

## ルール

静的型付け言語で関数・メソッドを定義する際は、**引数の型と戻り値の型を必ず明示する**。型推論に任せてはならない。

これは以下の理由による:

- **設計意図の明示** — 推論された型は「たまたまそうなった型」か「設計上そう決めた型」か区別できない。明示することで関数の型を契約（contract）として扱える
- **シグネチャ単独での可読性** — 関数本体を読まなくても、シグネチャだけで呼び出し側のコードを書ける／レビューできる
- **エラーの局所化** — 型不整合が発生したとき、どこが「意図された型」でどこが「逸脱」かをアノテーションが基準点として示す
- **公開境界の安定化** — 推論依存の戻り値型は内部実装の変更で意図せず変わる。明示すれば破壊的変更がコンパイル時に検出される

## 適用範囲

| 対象 | 型アノテーション |
|------|------|
| 関数の各引数 | 必須 |
| 関数の戻り値 | 必須 |
| メソッド（public / private 問わず） | 必須 |
| `export` / `pub` される関数 | 必須 |
| ローカル変数 | 任意（推論で OK） |
| ジェネリック型パラメータの制約 | 必要に応じて明示 |

ローカル変数は型推論で十分なケースが多いため、強制しない。明示するかどうかは可読性で判断する。

## 言語別の指針

### TypeScript

```typescript
// ✅ OK
function add(a: number, b: number): number {
  return a + b
}

const fetchUser = (id: string): Promise<User> => api.get(`/users/${id}`)

class UserService {
  findById(id: string): Promise<User | null> { ... }
}

// ❌ NG（戻り値の型を省略している）
function add(a: number, b: number) {
  return a + b
}

const fetchUser = (id: string) => api.get(`/users/${id}`)
```

**例外**: 配列メソッドなど高階関数に渡す短いコールバックは推論で OK（コールバックの型は呼び出し側のシグネチャで確定しているため）。

```typescript
// ✅ OK — コールバックの引数型・戻り値型は推論で問題ない
users.map(u => u.name)
items.filter(x => x.active)
```

### Python

```python
# ✅ OK
def add(a: int, b: int) -> int:
    return a + b

class UserService:
    def find_by_id(self, id: str) -> User | None: ...

# ❌ NG
def add(a, b):
    return a + b

def find_by_id(self, id):
    ...
```

**例外**:
- `__init__` の戻り値型 `-> None` は省略してよい（PEP 慣習）
- `self` / `cls` パラメータの型は不要

### Rust

引数の型は元々必須。**戻り値の型も `()` を含めて常に明示する**（`-> ()` 自体は省略可だが、それ以外は推論に頼らない）。

```rust
// ✅ OK
fn add(a: i32, b: i32) -> i32 { a + b }
fn log(msg: &str) { println!("{}", msg); } // 戻り値 () は省略 OK

// ❌ NG（impl Trait や複雑な戻り値で推論に頼って読み手が型を追えなくなる）
fn make_adder(x: i32) -> _ { move |y| x + y }
```

### Kotlin

```kotlin
// ✅ OK
fun add(a: Int, b: Int): Int = a + b

// ❌ NG（戻り値型を省略している）
fun add(a: Int, b: Int) = a + b
```

単一式関数でも戻り値型は明示する。

### Go

引数・戻り値の型は元々必須。**名前付き戻り値（named return values）を使う場合も型は省略しない**。
公開関数（大文字始まり）は特に厳格に守る。

```go
// ✅ OK
func Add(a int, b int) int { return a + b }
func ParseUser(data []byte) (User, error) { ... }
```

### Java / C# / Swift

これらの言語は元々関数シグネチャに型が必須。**ローカル変数の `var` / `let` 推論は許容するが、メソッドシグネチャは常に型を明示**する（言語の文法上強制されている）。

```java
// ✅ OK
public User findById(String id) { ... }

// ローカル変数は推論で OK
var user = userRepository.findById(id);
```

```swift
// ✅ OK
func findById(_ id: String) -> User? { ... }
```

## ルールから外れる必要がある場合

真に推論に任せた方が良い・任せざるを得ない箇所がある場合:

1. **実装を止める**
2. **理由を明示する**（なぜ明示できないのか／なぜ推論の方が適切なのか）
3. **ユーザーに許可を求める**

> 関数 `xxx` の戻り値型を推論に任せたい箇所があります。許可を求めます。
>
> **理由:** 戻り値型が複雑なジェネリック合成（例: `ReturnType<typeof someFactory>`）で、明示すると同じ型を二重定義することになり保守性を損ねます。
>
> 許可していただけますか？

## やってはいけないこと

- 戻り値型を省略して推論に任せる（公開関数・private メソッド問わず）
- 引数に `any` / `unknown` / `Object` などのトップ型を安易に置く（具体型または `unknown` + 型ガード／`zod` を検討する）
- 「ローカル変数だから」を理由に内部のヘルパー関数の型を省略する（関数である以上シグネチャは契約）
- 既存コードに合わせるという理由で型ヒントを省略する（既存コードが型ヒントを使っているなら同じ水準で書く）
