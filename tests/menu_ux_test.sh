#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../install.sh
source "${ROOT_DIR}/install.sh"

fail() {
    printf '[FAIL] %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    local expected="$1" actual="$2" message="$3"
    [[ "$actual" == "$expected" ]] || fail "${message}: expected=${expected@Q}, actual=${actual@Q}"
}

assert_contains() {
    local haystack="$1" needle="$2" message="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "${message}: missing=${needle@Q}"
}

assert_eq k30303030/ix-transit-fabric "$IXTF_PROJECT_REPO" "开发版默认仓库"
assert_eq dev "$IXTF_PROJECT_REF" "开发版默认分支"

profile_ids() { printf '%s\n' alpha beta; }
sorted_profile_ids() { printf '%s\n' alpha beta; }
profile_count() { printf '2\n'; }
load_profile() {
    PROFILE_ID="$1"
    ROLE="nat-ingress"
    ENABLED="true"
    HEALTH_STATUS="healthy"
    LINE_ROLE="standalone"
    FORWARD_ENABLED="true"
    return 0
}
rule_menu_rule_count() { printf '1\n'; }

selected="$(select_profile_from_menu "管理" <<<"2" 2>/dev/null)"
assert_eq beta "$selected" "多线路应按数字序号选择"

selected="$(select_profile_from_menu "管理" <<<'beta
2' 2>/dev/null)"
assert_eq beta "$selected" "菜单应拒绝线路 ID 后继续读取数字序号"

selected="$(select_profile_from_menu "管理" <<<'9
1' 2>/dev/null)"
assert_eq alpha "$selected" "越界序号后应继续读取有效序号"

if select_profile_from_menu "管理" <<<"0" >/dev/null 2>&1; then
    fail "输入 0 应返回上级菜单"
fi

profile_ids() { printf 'only-line\n'; }
sorted_profile_ids() { printf 'only-line\n'; }
profile_count() { printf '1\n'; }
selected="$(select_profile_from_menu "诊断" </dev/null 2>/dev/null)"
assert_eq only-line "$selected" "唯一线路应自动选择"

profile_groups() { printf '%s\n' group-a group-b; }
profile_group_count() { printf '2\n'; }
list_group_forwarding_profiles() { printf '%s-forwarding\n' "$1"; }
group_ready_state() { printf 'ready\n'; }
group_ready_state_label_zh() { printf '就绪\n'; }
selected="$(select_group_from_menu <<<"2" 2>/dev/null)"
assert_eq group-b "$selected" "线路组应按数字序号选择"

selected="$(select_group_from_menu <<<'group-b
1' 2>/dev/null)"
assert_eq group-a "$selected" "菜单应拒绝线路组名称后继续读取数字序号"

list_group_ingress_profiles() { printf '%s\n' alpha beta; }
selected="$(select_group_target_from_menu group-b <<<"1" 2>/dev/null)"
assert_eq alpha "$selected" "组内目标线路应按数字序号选择"

profile_groups() { printf 'only-group\n'; }
profile_group_count() { printf '1\n'; }
selected="$(select_group_from_menu </dev/null 2>/dev/null)"
assert_eq only-group "$selected" "唯一线路组应自动选择"

list_group_ingress_profiles() { printf 'only-target\n'; }
selected="$(select_group_target_from_menu only-group </dev/null 2>/dev/null)"
assert_eq only-target "$selected" "唯一组内目标线路应自动选择"

require_tty() { return 0; }
ensure_ix_cli_shortcut() { return 0; }
menu_output="$(show_menu <<<"0" 2>&1)"
for label in \
    '创建 / 接入线路' \
    '线路与转发管理' \
    '状态检查与故障诊断' \
    '自动运维' \
    '安装 / 更新 EasyTier' \
    '系统维护'; do
    assert_contains "$menu_output" "$label" "主菜单应展示任务式入口"
done

port_used_by_profile_rule() { return 1; }
nat_public_port_in_pool() { fail "未修改的商家入口端口不应重新校验端口池"; }
ROLE="nat-transit"
NAT_DIRECTION="nat-listener"
RULE_NOTE="旧备注"
LANDING_HOST="landing.example"
LANDING_PORT="443"
FORWARD_PROTO="both"
TRANSIT_PORT="30000"
NAT_PUBLIC_PORT="31000"
CLIENT_PORT=""
menu_edit_all_rule_fields alpha rule-main <<<$'新备注\n\n\n\n\n' 2>/dev/null
assert_eq 1 "$IXTF_RULE_EDIT_CHANGED" "全部修改应识别实际变更"
assert_eq 新备注 "$RULE_NOTE" "全部修改应保存新备注"
assert_eq landing.example "$LANDING_HOST" "落地地址回车应保留原值"
assert_eq 443 "$LANDING_PORT" "落地端口回车应保留原值"
assert_eq both "$FORWARD_PROTO" "协议回车应保留原值"
assert_eq 30000 "$TRANSIT_PORT" "中转端口回车应保留原值"
assert_eq 31000 "$NAT_PUBLIC_PORT" "商家入口端口回车应保留原值"

menu_edit_all_rule_fields alpha rule-main <<<$'\n\n\n\n\n' 2>/dev/null
assert_eq 0 "$IXTF_RULE_EDIT_CHANGED" "全部回车时不应标记规则变更"

ROLE="nat-ingress"
RULE_NOTE="入口旧备注"
CLIENT_PORT="32000"
menu_edit_all_rule_fields alpha rule-main <<<$'入口新备注\n' 2>/dev/null
assert_eq 1 "$IXTF_RULE_EDIT_CHANGED" "公网入口侧应允许修改本地属性"
assert_eq 入口新备注 "$RULE_NOTE" "公网入口侧应修改备注"
assert_eq 32000 "$CLIENT_PORT" "客户端入口端口回车应保留原值"

CALLED=""
show_create_menu() { CALLED="create"; }
show_profiles_menu() { CALLED="profiles"; }
show_diagnostics_menu() { CALLED="diagnostics"; }
show_automation_menu() { CALLED="automation"; }
install_easytier() { CALLED="easytier"; }
show_system_menu() { CALLED="system"; }

for mapping in \
    '1:create' \
    '2:profiles' \
    '3:diagnostics' \
    '4:automation' \
    '5:easytier' \
    '6:system'; do
    choice="${mapping%%:*}"
    expected="${mapping#*:}"
    CALLED=""
    run_menu_action "$choice"
    assert_eq "$expected" "$CALLED" "主菜单 ${choice} 分发"
done

if run_menu_action 0; then
    fail "主菜单 0 应返回退出状态"
else
    rc=$?
    assert_eq 10 "$rc" "主菜单退出状态"
fi

printf '[OK] 菜单与规则全量修改测试通过。\n'
