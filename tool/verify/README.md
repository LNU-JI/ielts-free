# tool/verify — 无需 Flutter 工具链的数据层验证脚本

这些脚本用**纯 Python 标准库**（`sqlite3` / `json` / `hashlib`）对仓库做静态与数据层验证，
**不需要安装 Flutter / Dart / Android SDK**。它们由 QA 工程师在开发期编写并真实执行过。

用途：在没有 Flutter 环境的机器上（例如本项目的构建机），仍能验证
**内容库完整性、schema 双源一致性、数据库迁移不丢数据、列名拼写、离线红线**。

## 运行

```bash
# 在仓库根目录（ielts_free/）执行
python tool/verify/verify_content.py
python tool/verify/verify_migration.py
```

脚本会自动把仓库根解析为「本文件所在目录的上两级」，因此可在任意位置调用。

## 脚本清单

| 脚本 | 验证内容 |
| --- | --- |
| `verify_content.py` | 内容库文件 SHA256 与 `manifest.checksum` 是否一致；`integrity_check`；行数与 manifest 计数是否吻合；题型分布；**只读打开时写操作必须失败**；`kContentSchemaSql` 与 `content_pipeline/schema.sql` 是否逐句相同 |
| `verify_migration.py` | 从 `schema_user.dart` 解析 v1 DDL、从 `migrations.dart` 解析 v2 语句，**在临时 SQLite 里真实执行迁移**，断言：全部表与行数保留、关键字段值不变、新列与默认值就位、索引建成、`foreign_key_check` 为空、`user_version` 正确、DDL 无 `DROP`/`DELETE` |
| `colcheck.py` | 交叉核对 Dart 源码中引用的 SQL 列名与真实表结构，查拼写错误 |
| `schema_diff.py` | 比对内容库 schema 的双份来源（Dart 常量 vs `schema.sql`） |
| `inspect_cols.py` | 打印内容库各表的真实列名与 manifest 内容，便于人工核对 |
| `dartcheck.py` | Dart 文件括号配平与 `void main(` 存在性检查（粗糙但有效的语法体检） |
| `plan_core.py` / `per_dm.py` / `sweep.py` / `sweep3.py` | 每日任务分配算法的**纯 Python 复刻**，用于穷举验证「`Σminutes == dailyMinutes` 且每项 ≥5」不变量 |
| `verify_daily_plan_floor.py` | **独立穷举复验修复后的 `_fixSum`**：1:1 移植新算法并对照旧算法，断言两条不变量（精确求和 + 每项 ≥5）。当前结果：2,167,448 组用例，新算法 0 违规、旧算法 204,516 违规 |

## 注意

- 这些是**开发期辅助工具**，不属于 App 运行时的一部分，也不会被编译进产物。
- `dartcheck.py` 只是粗粒度的语法体检，**不能替代 `flutter analyze`**。
- 真正的编译与测试收口仍需 `flutter analyze` + `flutter test`（见 `.github/workflows/tests.yml`）。
