# Package B — local deployment and design

Owner: Zhihao Zhang · Week 8 checkpoint · Compiled 17 September 2026

## Start here

1. [What B actually deployed this week / 本周部署全过程](LOCAL_DEPLOYMENT_WEEK8.md).
2. [Reproduce the local setup](B_release_v0.1/B_setup_readme.md), using the complete `B_release_v0.1` folder.
3. [Recorded local validation](B_release_v0.1/evidence/B_local_validation.json) and [CloudBeaver connection evidence](B_release_v0.1/evidence/B_browser_connection_check.md).
4. [Architecture and proposed models (PDF)](B_release_v0.1/B_design_v0.1.pdf), [editable drawio](B_release_v0.1/B_design_v0.1.drawio), and [logical dictionary](B_release_v0.1/B_logical_dictionary_v0.1.md).
5. [Peer reproduction / design review record](B_release_v0.1/B_peer_check.md) and [integration checklist](B_release_v0.1/B_release_checklist.md).
6. [Chinese beginner walkthrough / 中文讲解](B_release_v0.1/B_teaching_CN.md).

**Verified on B's local machine on 16 September:** PostgreSQL 15.18; `glucolink_a2`; eight project schemas plus default `public`; zero business tables/views at the B-only baseline. First run, repeated run, wrong-database rejection and browser connection passed. Existing course practice tables remained readable with the recorded row counts.

**Pending:** another member's reproduction, D/E model review and F's integrated run. The diagrams describe proposed business objects; B's setup creates schema namespaces only. Cloud hosting and automatic monitoring have not been deployed.

The SQL, runner and evidence retain the locally tested release contents. The setup readme uses portable paths for teammates; its checksum manifest has been regenerated for this repository copy. Evidence files describe the recorded September 16 runs, not a new execution on September 17.
