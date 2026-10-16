# POF清单

已完成核验

按功能从少到多排列；本清单仅列实际存在文件并给出SHA-256。

| 阶段 | POF | LE | SHA-256 |
|---|---|---:|---|
| 0 | [step0_original_SW6_readback_1089LE.pof](E:/codex/数电实验2/radar/p5a/restart/pofs/step0_original_SW6_readback_1089LE.pof) | 1089 | `709218e16d4b0618bd6656a9ba09ba896add2ad8b9cbeaec44ec7c943fa4dfd3` |
| 1 | [step1_A0_pending_snapshot_syncSW7_1101LE.pof](E:/codex/数电实验2/radar/p5a/restart/pofs/step1_A0_pending_snapshot_syncSW7_1101LE.pof) | 1101 | `eb47b63467e0c306381902f1d18c6fcfaf82011199c92ae02dd99059ec6de0d1` |
| 2 | [step2_A0_pending_snapshot_syncSW7_UFM_1225LE.pof](E:/codex/数电实验2/radar/p5a/restart/pofs/step2_A0_pending_snapshot_syncSW7_UFM_1225LE.pof) | 1225 | `73051dbaf410269866862823816719e3036ebcc88f7383984c4670983153e464` |
| 3 | [step3_A0_pending_snapshot_syncSW7_UFM_alarmInverse_1253LE.pof](E:/codex/数电实验2/radar/p5a/restart/pofs/step3_A0_pending_snapshot_syncSW7_UFM_alarmInverse_1253LE.pof) | 1253 | `67332205e468962a8a7a9a475d2eab27594de9549e2a1dde77653211edc4f50a` |

第0项为P5a-0原版回退。第1项包含1a/1b；第2项再加UFM背景；第3项再加报警反显。

第4至7项未保留新功能；回退POF已验证与第3项逐字节相同，以下均为已归档文件。

- 第4项 [step4_unchanged_after_XOR_beam_reverted_1253LE.pof](E:/codex/数电实验2/radar/p5a/restart/pofs/step4_unchanged_after_XOR_beam_reverted_1253LE.pof)：与第3项逐字节一致，SHA-256 `67332205e468962a8a7a9a475d2eab27594de9549e2a1dde77653211edc4f50a`。
- 第5项 [step5_unchanged_after_dynamicDigits_reverted_1253LE.pof](E:/codex/数电实验2/radar/p5a/restart/pofs/step5_unchanged_after_dynamicDigits_reverted_1253LE.pof)：与第3项逐字节一致，SHA-256 `67332205e468962a8a7a9a475d2eab27594de9549e2a1dde77653211edc4f50a`。
- 第6项 [step6_unchanged_after_modeWord_reverted_1253LE.pof](E:/codex/数电实验2/radar/p5a/restart/pofs/step6_unchanged_after_modeWord_reverted_1253LE.pof)：与第3项逐字节一致，SHA-256 `67332205e468962a8a7a9a475d2eab27594de9549e2a1dde77653211edc4f50a`。
- 第7项 [step7_unchanged_after_levelBar_reverted_1253LE.pof](E:/codex/数电实验2/radar/p5a/restart/pofs/step7_unchanged_after_levelBar_reverted_1253LE.pof)：与第3项逐字节一致，SHA-256 `67332205e468962a8a7a9a475d2eab27594de9549e2a1dde77653211edc4f50a`。

烧录必须同时对CFM和UFM勾选Program，并执行Verify；POF内数据验证不等于已对板上器件烧录或校验。
