#!/usr/bin/env bash
#
# analyze.sh — автоанализ дизассемблера для задания «Деление на 0 даст 0».
#
set -u

SRC_DIR="src"
OUT_DIR="out"
RESULTS="$OUT_DIR/results.txt"
mkdir -p "$OUT_DIR"

BUILDS=(
  "demo_gcc_O0|gcc|-O0"
  "demo_gcc_O3|gcc|-O3"
  "demo_clang_O0|clang|-O0"
  "demo_clang_O3|clang|-O3"
)

hr() { printf '%s\n' "------------------------------------------------------------"; }

build_one() {
    local bin="$1" cc="$2" opt="$3"
    echo ">>> Сборка $bin ($cc $opt)"
    "$cc" "$opt" -g -o "$bin" \
        "$SRC_DIR/main.cpp" \
        "$SRC_DIR/scenarios.cpp" \
        "$SRC_DIR/handler.cpp" 2> "$OUT_DIR/$bin.build.log"
    [[ $? -ne 0 ]] && { echo "!!! Ошибка сборки $bin"; return 1; }
    return 0
}

run_one() {
    local bin="$1"
    local log="$OUT_DIR/$bin.run.log"
    ./"$bin" > "$log" 2>&1
    local rc=$?
    echo ">>> Запуск $bin (rc=$rc)"
    cat "$log"
}

# Деманглирование имён C++ через c++filt + отбрасывание суффиксов .constprop.N
resolve_symbol() {
    local bin="$1" base="$2"
    while read -r addr type sym; do
        [[ "$type" =~ ^[TtWw]$ ]] || continue
        local dem
        dem=$(printf '%s\n' "$sym" | c++filt 2>/dev/null)
        dem="${dem%%(*}"          # убрать сигнатуру
        local base_dem="${dem%%.*}"   # убрать .constprop/.isra/.part
        if [[ "$dem" == "$base" || "$base_dem" == "$base" ]]; then
            printf '%s\n' "$sym"
            return 0
        fi
    done < <(nm "$bin" 2>/dev/null | awk '$2 ~ /^[TtWw]$/ {print $1, $2, $3}')
    return 1
}

dump_function() {
    local bin="$1" sym="$2" outfile="$3"
    objdump -d --no-show-raw-insn --disassemble="$sym" "$bin" \
        > "$outfile" 2>/dev/null
    if ! grep -q "<$sym>:" "$outfile"; then
        objdump -dC --no-show-raw-insn "$bin" \
            | awk -v s="$sym" '
                $0 ~ "<"s"[(\\(<]" {p=1}
                p {print}
                p && /^$/ {exit}
            ' > "$outfile"
    fi
}

has_div_instruction() {
    local bin="$1" sym="$2"
    objdump -d --disassemble="$sym" "$bin" 2>/dev/null \
        | grep -E '\b(idiv|div)[bwlq]?\b' | grep -v '//' | head -1
}

has_branch() {
    local bin="$1" sym="$2"
    objdump -d --no-show-raw-insn --disassemble="$sym" "$bin" 2>/dev/null \
        | grep -E '\b(test|cmp)\b' -A2 \
        | grep -E '\bj(e|ne|z|nz)\b' | head -1
}

verdict() {
    local log="$1" scen="$2"
    grep -E "$scen: b is (0|NOT 0)" "$log" | head -1
}

sigfpe_count() {
    local log="$1"
    grep -oE 'Перехвачено SIGFPE: [0-9]+' "$log" | grep -oE '[0-9]+'
}

hr; echo "ШАГ 1. Сборка"; hr
for entry in "${BUILDS[@]}"; do
    IFS='|' read -r bin cc opt <<< "$entry"
    build_one "$bin" "$cc" "$opt" || exit 1
done

hr; echo "ШАГ 2. Запуск"; hr
for entry in "${BUILDS[@]}"; do
    IFS='|' read -r bin _ _ <<< "$entry"
    hr
    run_one "$bin"
done

hr; echo "ШАГ 3. Дизассемблер (сохранён в $OUT_DIR/)"; hr
for entry in "${BUILDS[@]}"; do
    IFS='|' read -r bin _ _ <<< "$entry"
    for fn in scenario_A scenario_B; do
        sym=$(resolve_symbol "$bin" "$fn")
        if [[ -z "$sym" ]]; then
            echo "  $bin: $fn — символ не найден"
            continue
        fi
        dump_function "$bin" "$sym" "$OUT_DIR/$bin.$fn.asm"
        echo "  $bin: $fn → '$sym' → $OUT_DIR/$bin.$fn.asm"
    done
done

hr; echo "ШАГ 4. Сводка"; hr
printf '%-16s %-4s | %-22s | %-22s | %s\n' \
    "Бинарник" "SIG" "A (div / ветка)" "B (div / ветка)" "B: вывод"
printf '%-16s %-4s-+-%-22s-+-%-22s-+-%s\n' \
    "----------------" "----" "----------------------" \
    "----------------------" "-----------"

{
    echo "=== СВОДНАЯ ТАБЛИЦА ==="
    for entry in "${BUILDS[@]}"; do
        IFS='|' read -r bin _ _ <<< "$entry"
        log="$OUT_DIR/$bin.run.log"
        sig=$(sigfpe_count "$log"); [[ -z "$sig" ]] && sig="?"

        symA=$(resolve_symbol "$bin" scenario_A)
        divA=$([[ -n "$symA" ]] && has_div_instruction "$bin" "$symA" >/dev/null && echo yes || echo no)
        brA=$([[ -n "$symA" ]] && has_branch "$bin" "$symA" >/dev/null && echo yes || echo no)

        symB=$(resolve_symbol "$bin" scenario_B)
        divB=$([[ -n "$symB" ]] && has_div_instruction "$bin" "$symB" >/dev/null && echo yes || echo no)
        brB=$([[ -n "$symB" ]] && has_branch "$bin" "$symB" >/dev/null && echo yes || echo no)

        vB=$(verdict "$log" "B"); [[ -z "$vB" ]] && vB="?"

        printf '%-16s %-4s | div:%-3s br:%-3s       | div:%-3s br:%-3s       | %s\n' \
            "$bin" "$sig" "$divA" "$brA" "$divB" "$brB" "$vB"
    done
} | tee "$RESULTS"

echo
echo "Полный отчёт: $RESULTS"
echo "Дампы:        $OUT_DIR/*.asm"
echo "Логи:         $OUT_DIR/*.build.log $OUT_DIR/*.run.log"