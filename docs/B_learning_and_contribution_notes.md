# B personal explanation, presentation and contribution worksheet

Owner: Zhihao Zhang. AI-assisted preparation on 2026-10-06. Practice material; not a claim of understanding, hours worked or peer approval.

## 60–90 second English explanation

I set up the shared PostgreSQL database environment with a browser interface so our group can work against the same database. For Package B, I prepared a repeatable setup script that documents eight schemas, preserves pipeline history and loads our nine agreed rule parameters atomically. I tested the script in isolated databases, including a restored copy, before applying the coordinated shared update and saving verification evidence.

I also prepared the laboratory fixture loader with 36 messages and 34 deliveries, including the intentional quality and delivery exceptions. It has passed component tests, but its shared load must wait for C's final source-data handoff. I created the architecture and conceptual diagrams and a logical dictionary/report draft, marking unfinished D/E structures for review. The remaining integration work is to load after C, confirm the final models with D/E, and run the frozen 00–10 pipeline twice with F. I have kept those pending tasks separate from verified results.

## 从零理解：你实际负责的几层

1. **服务器**是一台一直开着的远程电脑。PostgreSQL 是保管数据、检查规则并执行 SQL 的程序。CloudBeaver 是打开它的网页操作界面。GitHub 保存“建造说明书”——SQL 和文档，不是数据库正在变化的全部内容。
2. **数据库**像这项作业的一座图书馆，**schema**像分区，**表**像一类登记册，**行**是一条记录，**列**是每条记录要填的项目。8 个 schema 不是8份自动互相复制的数据库。
3. **00_setup.sql**搭好分区、写清用途，建两本公共登记册。pipeline_run 记每次流水线运行；rule_parameter 放大家共同使用的规则数值。日志不会自动记录每个队友的每条SQL，也不能凭它推断是谁手工改了哪行。
4. **参数表**像统一的考试评分规则。九条规则按名称取值，比如 as_of_date 是观察日期。数值储存为文字，所以计算前必须转成日期或数字。只有“九行”不够：九个名字和九个值都要正确。
5. **事务**像密封的一袋更新：全部检查通过才提交；任何一处失败就撤回整袋。TRUNCATE 是清空当前行；INSERT 是放入新行。两者放同一事务中，别人不会看到已经提交的“半份参数”。但短时间会需要锁，所以要约好写入暂停，等锁超过5秒就停。
6. **02b**只负责放化验资料，不负责替 C 创建表。36条消息里包括特意设计的重复、空单位和未来日期。34条送达记录表示两个消息没有送达记录；异常是用于验证规则的测试题，不能随手修好。
7. **RAW→CLEANSED→CURATED**像保留原卷、核对纠错、整理成统计用表。按新版规则，CURATED还可以读取RAW里的机构等参考资料。B画结构和准备公共基础；不直接改 D/E 的算法。
8. **事实表的一行含义（grain）**决定统计有没有重复。两次化验和三次配药直接按患者相连会产生六行；应先各自汇总，再合并指标。

## 答辩问题与可以证明的回答

|问题|回答要点|证据位置|
|---|---|---|
|为什么用 IF NOT EXISTS？|空库能建立、重复执行不因对象已存在失败；但它不会自动修复旧表结构差异，所以发布前仍要对照结构|00 + 空库/恢复副本测试|
|为什么不 DROP 日志表？|会丢掉历史、对象身份、权限和依赖；我们只创建缺少的对象|00、共享发布前后对比|
|怎样证明没破坏别人？|新分支只改B文件；备份和副本测试；事务；比较非目标表内容、结构、权限、视图和序列|PR差异、发布记录|
|为什么不是只数行？|不同内容可能有同样行数；参数要按名字和值比较，消息要逐条比较JSON和引用|00断言、02b比较|
|谁先做你才能导入？|C先建表并完成最后一次02及父记录；B再02b；C/D/E按依赖继续；F最后测试|B交接手册|
|为什么36消息不等于36事实？|质量过滤和身份链接决定入事实：重复、坏单位、未来日期、未解决身份都可能被排除|目标规则；最终由D/E/F验收|
|为什么不用名字直接匹配？|同名或缺信息会误连；唯一规则可连接，歧义保留REVIEW|概念模型、D匹配规则|
|服务器UTC会不会错？|存储时间点与临床日期不同；必须先解析带时区时间，再取Australia/Sydney日期|D实现与最终时区测试|
|回滚怎么做？|提交前事务回滚；提交后先比较新修改，在副本验证只恢复受影响对象|恢复手册|
|现在能说全部完成吗？|不能；00及组件验证完成，02b共享导入、D/E确认、完整重跑和看板验收有明确前置条件|状态表|
|你如何使用AI？|AI协助整理、编写和检查；保留实际证据并由本人理解解释，不声称未做的人工作业或工时|本说明及贡献记录|

## 每阶段复述练习（需本人回答，尚未完成）

- 用自己的话解释“服务器、数据库、schema、表、SQL文件”五者关系。
- 解释参数加载为什么要一个事务，并说出出现锁超时后的结果。
- 指出消息表和送达表的一行分别代表什么，解释36/34。
- 找出数据字典里一个已观测字段和一个待确认字段，解释两者证据差别。
- 用“两次化验×三次配药”解释事实表直接相连为什么会统计错误。
- 说出C、D/E、F分别要给你什么，才允许你把剩余项目标成完成。

## Contribution log draft — fill only B's rows after checking the workbook headings

|Date|Activity|Result / evidence|Status|Hours|
|---|---|---|---|---|
|2026-10-06|Prepare portable 00 setup and nine final parameters|PR #3; isolated rerun/restore tests|Verified component work|User to supply|
|2026-10-06|Coordinated shared 00 release|Private backup, eight comments/nine parameters, preserved non-target content; screenshots|Verified release|User to supply|
|2026-10-06|Prepare 36/34 lab fixture loader|PR #4; twelve component scenarios across B scripts|Shared load pending C|User to supply|
|2026-10-06|Architecture and conceptual design|PR #5 PNG + editable files|D/E review pending|User to supply|
|2026-10-06|Read live metadata and draft full dictionary/logical model/report|B-only documents; observed versus proposed clearly marked|Draft pending owner review|User to supply|
|2026-10-06|Environment and dashboard readiness check|PostgreSQL/timezone/roles/resources; deployment and Excel fallback procedure|No dashboard deployment claim|User to supply|

Earlier shared-environment work may be added by Zhihao with its actual dates and evidence. Do not backdate entries or allocate another member's work to B. The shared contribution workbook is not edited by this document. Personal signatures and peer acknowledgement must be supplied by the people concerned.
