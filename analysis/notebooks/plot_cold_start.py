"""
Análise experimental do impacto de arquitetura e memória no cold start (Init Duration)
de funções AWS Lambda.

Uso:
    python plot_cold_start.py [init_duration_results.csv] [metrics.csv] [pasta_saida]

Dependências: pandas, numpy, matplotlib, scipy
    pip install pandas numpy matplotlib scipy
"""
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats

# ----------------------------------------------------------------------------
# Configuração
# ----------------------------------------------------------------------------
RAW_CSV = sys.argv[1] if len(sys.argv) > 1 else "../../results/init_duration_results.csv"
METRICS_CSV = sys.argv[2] if len(sys.argv) > 2 else "../../results/metrics.csv"
OUT = Path(sys.argv[3] if len(sys.argv) > 3 else "figuras")
OUT.mkdir(parents=True, exist_ok=True)

COLORS = {"arm64": "#1b7f79", "x86_64": "#d1603d"}
LABELS = {"arm64": "ARM64 (Graviton2)", "x86_64": "x86_64"}
ARCHS = ["arm64", "x86_64"]

plt.rcParams.update({
    "figure.dpi": 110,
    "savefig.dpi": 300,
    "savefig.bbox": "tight",
    "font.size": 10,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.alpha": 0.25,
    "axes.axisbelow": True,
})

raw = pd.read_csv(RAW_CSV)
met = pd.read_csv(METRICS_CSV)
mems = sorted(raw["memory_size"].unique())
xpos = np.arange(len(mems))
mem_labels = [str(m) for m in mems]


def save(fig, name):
    path = OUT / name
    fig.savefig(path)
    plt.close(fig)
    print(f"[ok] {path}")


def piv(col):
    """Pivota a tabela de métricas: linhas = memória, colunas = arquitetura."""
    return met.pivot(index="memory_size", columns="architecture", values=col).loc[mems]


# ----------------------------------------------------------------------------
# Fig 1 - Boxplots da distribuição bruta (visão geral do fenômeno)
# Importância: mostra forma, dispersão e outliers que média/mediana escondem.
# ----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 5))
w = 0.35
for i, arch in enumerate(ARCHS):
    data = [raw[(raw.architecture == arch) & (raw.memory_size == m)]["init_duration_ms"] for m in mems]
    bp = ax.boxplot(
        data, positions=xpos + (i - 0.5) * w, widths=w * 0.85, patch_artist=True,
        showfliers=True, flierprops=dict(marker="o", markersize=3, alpha=0.5,
                                         markeredgecolor=COLORS[arch]),
        medianprops=dict(color="black", linewidth=1.5),
    )
    for patch in bp["boxes"]:
        patch.set_facecolor(COLORS[arch])
        patch.set_alpha(0.65)
ax.set_xticks(xpos)
ax.set_xticklabels(mem_labels)
ax.set_xlabel("Memória alocada (MB)")
ax.set_ylabel("Init Duration (ms)")
ax.set_title("Distribuição do Init Duration por arquitetura e memória (n = 100 por cenário)")
ax.legend(handles=[plt.Rectangle((0, 0), 1, 1, color=COLORS[a], alpha=0.65) for a in ARCHS],
          labels=[LABELS[a] for a in ARCHS], loc="upper right")
save(fig, "fig1_boxplot_distribuicao.png")

# ----------------------------------------------------------------------------
# Fig 2 - Mediana (e média) por memória
# Importância: a mediana é a medida de tendência central robusta a outliers,
# adequada para dados de latência (assimétricos à direita).
# ----------------------------------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(12, 4.5), sharey=True)
for ax, col, title in zip(axes, ["median", "mean"], ["Mediana", "Média"]):
    d = piv(col)
    for arch in ARCHS:
        ax.plot(xpos, d[arch], marker="o", color=COLORS[arch], label=LABELS[arch], linewidth=2)
        for x, y in zip(xpos, d[arch]):
            ax.annotate(f"{y:.1f}", (x, y), textcoords="offset points",
                        xytext=(0, 7 if arch == "x86_64" else -13), ha="center",
                        fontsize=8, color=COLORS[arch])
    ax.set_xticks(xpos)
    ax.set_xticklabels(mem_labels)
    ax.set_xlabel("Memória alocada (MB)")
    ax.set_title(f"{title} do Init Duration")
axes[0].set_ylabel("Init Duration (ms)")
axes[0].legend()
save(fig, "fig2_mediana_media.png")

# ----------------------------------------------------------------------------
# Fig 3 - Variância e desvio padrão
# Importância: quantifica a previsibilidade do cold start entre os cenários.
# ----------------------------------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
for ax, col, title, ylabel in zip(axes, ["var", "std"],
                                  ["Variância", "Desvio padrão"], ["ms²", "ms"]):
    d = piv(col)
    for i, arch in enumerate(ARCHS):
        ax.bar(xpos + (i - 0.5) * w, d[arch], w, color=COLORS[arch], label=LABELS[arch], alpha=0.85)
    ax.set_xticks(xpos)
    ax.set_xticklabels(mem_labels)
    ax.set_xlabel("Memória alocada (MB)")
    ax.set_ylabel(ylabel)
    ax.set_title(f"{title} do Init Duration")
axes[0].legend()
save(fig, "fig3_variancia_desvio.png")

# ----------------------------------------------------------------------------
# Fig 4 - Amplitude (max - min) e coeficiente de variação
# Importância: amplitude mostra o pior caso de oscilação; o CV normaliza a
# dispersão pela média e permite comparar cenários com médias diferentes.
# ----------------------------------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
for ax, col, title, ylabel in zip(axes, ["amp", "cv"],
                                  ["Amplitude (máx − mín)", "Coeficiente de variação"],
                                  ["ms", "CV (%)"]):
    d = piv(col)
    for i, arch in enumerate(ARCHS):
        bars = ax.bar(xpos + (i - 0.5) * w, d[arch], w, color=COLORS[arch],
                      label=LABELS[arch], alpha=0.85)
        for b in bars:
            ax.annotate(f"{b.get_height():.0f}", (b.get_x() + b.get_width() / 2, b.get_height()),
                        textcoords="offset points", xytext=(0, 2), ha="center", fontsize=7)
    ax.set_xticks(xpos)
    ax.set_xticklabels(mem_labels)
    ax.set_xlabel("Memória alocada (MB)")
    ax.set_ylabel(ylabel)
    ax.set_title(title)
axes[0].legend()
save(fig, "fig4_amplitude_cv.png")

# ----------------------------------------------------------------------------
# Fig 5 - Ganho percentual de ARM64 sobre x86_64
# Importância: responde diretamente "qual arquitetura é mais rápida e por
# quanto". Positivo = ARM64 mais rápida (menor init duration).
# ganho (%) = (x86 - arm) / x86 * 100
# ----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(11, 5))
metrics_gain = [("median", "Mediana"), ("mean", "Média"), ("p95", "P95"), ("p99", "P99")]
wg = 0.2
gain_table = {}
for i, (col, name) in enumerate(metrics_gain):
    d = piv(col)
    gain = (d["x86_64"] - d["arm64"]) / d["x86_64"] * 100
    gain_table[name] = gain
    ax.bar(xpos + (i - 1.5) * wg, gain, wg, label=name, alpha=0.9)
ax.axhline(0, color="black", linewidth=0.8)
ax.set_xticks(xpos)
ax.set_xticklabels(mem_labels)
ax.set_xlabel("Memória alocada (MB)")
ax.set_ylabel("Ganho do ARM64 sobre x86_64 (%)")
ax.set_title("Redução percentual do Init Duration do ARM64 em relação ao x86_64\n"
             "(positivo = ARM64 mais rápido)")
ax.legend(ncol=4, loc="upper left")
save(fig, "fig5_ganho_percentual_arm_vs_x86.png")

# ----------------------------------------------------------------------------
# Fig 6 - Cauda da distribuição: mediana, P95 e P99
# Importância: SLAs são definidos por percentis altos, não pela média.
# ----------------------------------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(12, 4.5), sharey=True)
for ax, arch in zip(axes, ARCHS):
    sub = met[met.architecture == arch].set_index("memory_size").loc[mems]
    ax.plot(xpos, sub["median"], marker="o", label="Mediana", color="#444444")
    ax.plot(xpos, sub["p95"], marker="s", label="P95", color=COLORS[arch])
    ax.plot(xpos, sub["p99"], marker="^", label="P99", color=COLORS[arch], linestyle="--")
    ax.fill_between(xpos, sub["median"], sub["p99"], color=COLORS[arch], alpha=0.12)
    ax.set_xticks(xpos)
    ax.set_xticklabels(mem_labels)
    ax.set_xlabel("Memória alocada (MB)")
    ax.set_title(LABELS[arch])
axes[0].set_ylabel("Init Duration (ms)")
axes[0].legend()
save(fig, "fig6_cauda_p95_p99.png")

# ----------------------------------------------------------------------------
# Fig 7 - ECDF por arquitetura (todas as memórias agrupadas)
# Importância: compara as distribuições completas, não só resumos estatísticos.
# ----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(8, 5))
for arch in ARCHS:
    v = np.sort(raw.loc[raw.architecture == arch, "init_duration_ms"].values)
    ax.step(v, np.arange(1, len(v) + 1) / len(v), where="post",
            color=COLORS[arch], label=f"{LABELS[arch]} (n={len(v)})", linewidth=2)
ax.set_xlabel("Init Duration (ms)")
ax.set_ylabel("Probabilidade acumulada")
ax.set_title("ECDF do Init Duration por arquitetura (todas as memórias)")
ax.legend(loc="lower right")
save(fig, "fig7_ecdf_arquiteturas.png")

# ----------------------------------------------------------------------------
# Fig 8 - Heatmap das medianas e dos desvios padrão
# Importância: visão compacta do espaço arquitetura x memória.
# ----------------------------------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(12, 3.6))
for ax, col, title, cmap in zip(axes, ["median", "std"],
                                ["Mediana (ms)", "Desvio padrão (ms)"], ["YlGnBu", "OrRd"]):
    mat = met.pivot(index="architecture", columns="memory_size", values=col).loc[ARCHS, mems]
    im = ax.imshow(mat.values, cmap=cmap, aspect="auto")
    ax.set_xticks(range(len(mems)))
    ax.set_xticklabels(mem_labels)
    ax.set_yticks(range(2))
    ax.set_yticklabels([LABELS[a] for a in ARCHS])
    ax.grid(False)
    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            ax.text(j, i, f"{mat.values[i, j]:.1f}", ha="center", va="center", fontsize=9)
    ax.set_title(title)
    ax.set_xlabel("Memória alocada (MB)")
    fig.colorbar(im, ax=ax, fraction=0.04, pad=0.02)
save(fig, "fig8_heatmap_mediana_desvio.png")

# ----------------------------------------------------------------------------
# Fig 9 - Efeito da memória: dispersão com reta de tendência (log2 da memória)
# Importância: testa visualmente se mais memória reduz o cold start.
# ----------------------------------------------------------------------------
fig, axes = plt.subplots(1, 2, figsize=(12, 4.5), sharey=True)
for ax, arch in zip(axes, ARCHS):
    sub = raw[raw.architecture == arch]
    xs = np.log2(sub["memory_size"].values)
    jitter = np.random.default_rng(42).normal(0, 0.03, len(xs))
    ax.scatter(xs + jitter, sub["init_duration_ms"], s=6, alpha=0.3, color=COLORS[arch])
    slope, intercept, r, p, _ = stats.linregress(xs, sub["init_duration_ms"])
    xl = np.linspace(xs.min(), xs.max(), 50)
    ax.plot(xl, intercept + slope * xl, color="black", linewidth=1.8,
            label=f"inclinação = {slope:.2f} ms/log2(MB)\nR² = {r**2:.3f}, p = {p:.3f}")
    ax.set_xticks(np.log2(mems))
    ax.set_xticklabels(mem_labels)
    ax.set_xlabel("Memória alocada (MB, escala log2)")
    ax.set_title(LABELS[arch])
    ax.legend(loc="upper right", fontsize=8)
axes[0].set_ylabel("Init Duration (ms)")
save(fig, "fig9_regressao_memoria.png")

# ----------------------------------------------------------------------------
# Testes estatísticos (impressos no terminal)
# ----------------------------------------------------------------------------
print("\n" + "=" * 78)
print("TESTES ESTATÍSTICOS")
print("=" * 78)

# 1) ARM vs x86 por memória (Mann-Whitney U, não paramétrico)
rows = []
for m in mems:
    a = raw[(raw.architecture == "arm64") & (raw.memory_size == m)]["init_duration_ms"]
    x = raw[(raw.architecture == "x86_64") & (raw.memory_size == m)]["init_duration_ms"]
    u, p = stats.mannwhitneyu(a, x, alternative="two-sided")
    # tamanho de efeito: rank-biserial
    rbc = 1 - 2 * u / (len(a) * len(x))
    rows.append({"memoria_MB": m, "mediana_arm": a.median(), "mediana_x86": x.median(),
                 "ganho_mediana_%": (x.median() - a.median()) / x.median() * 100,
                 "U": u, "p_valor": p, "rank_biserial": rbc,
                 "signif_5%": p < 0.05})
mw = pd.DataFrame(rows)
print("\nMann-Whitney U (ARM64 vs x86_64) por nível de memória:")
print(mw.round(4).to_string(index=False))
mw.to_csv(OUT / "teste_mannwhitney_por_memoria.csv", index=False)

# 2) Global ARM vs x86
a_all = raw[raw.architecture == "arm64"]["init_duration_ms"]
x_all = raw[raw.architecture == "x86_64"]["init_duration_ms"]
u, p = stats.mannwhitneyu(a_all, x_all, alternative="two-sided")
print(f"\nGlobal: mediana ARM = {a_all.median():.2f} ms | mediana x86 = {x_all.median():.2f} ms "
      f"| ganho = {(x_all.median() - a_all.median()) / x_all.median() * 100:.2f}% "
      f"| Mann-Whitney p = {p:.2e}")
print(f"Global: média ARM = {a_all.mean():.2f} ms | média x86 = {x_all.mean():.2f} ms")

# 3) Efeito da memória: Kruskal-Wallis por arquitetura + Spearman
print("\nEfeito da memória (por arquitetura):")
for arch in ARCHS:
    sub = raw[raw.architecture == arch]
    groups = [g["init_duration_ms"].values for _, g in sub.groupby("memory_size")]
    h, pk = stats.kruskal(*groups)
    rho, ps = stats.spearmanr(sub["memory_size"], sub["init_duration_ms"])
    print(f"  {arch:7s} Kruskal-Wallis H = {h:7.3f} (p = {pk:.4f}) | "
          f"Spearman rho = {rho:+.3f} (p = {ps:.4f})")

# 4) Homogeneidade de variâncias ARM vs x86 (Levene)
lev, pl = stats.levene(a_all, x_all)
print(f"\nLevene (variâncias ARM vs x86, global): W = {lev:.3f}, p = {pl:.4f}")
print(f"Variância média por arquitetura: ARM = {met[met.architecture=='arm64']['var'].mean():.1f} ms² | "
      f"x86 = {met[met.architecture=='x86_64']['var'].mean():.1f} ms²")
print(f"CV médio: ARM = {met[met.architecture=='arm64']['cv'].mean():.2f}% | "
      f"x86 = {met[met.architecture=='x86_64']['cv'].mean():.2f}%")
print(f"Amplitude média: ARM = {met[met.architecture=='arm64']['amp'].mean():.1f} ms | "
      f"x86 = {met[met.architecture=='x86_64']['amp'].mean():.1f} ms")

# 5) Ganhos percentuais (tabela)
gt = pd.DataFrame(gain_table)
gt.insert(0, "memoria_MB", mems)
print("\nGanho % do ARM64 sobre x86_64 (positivo = ARM mais rápido):")
print(gt.round(2).to_string(index=False))
gt.to_csv(OUT / "ganho_percentual_arm_vs_x86.csv", index=False)

# 6) Conferência: métricas recomputadas dos dados brutos vs metrics.csv
chk = (raw.groupby(["architecture", "memory_size"])["init_duration_ms"]
       .agg(mean="mean", median="median", std="std").reset_index())
chk = chk.merge(met[["architecture", "memory_size", "mean", "median", "std"]],
                on=["architecture", "memory_size"], suffixes=("_raw", "_csv"))
dif = max((chk["mean_raw"] - chk["mean_csv"]).abs().max(),
          (chk["median_raw"] - chk["median_csv"]).abs().max(),
          (chk["std_raw"] - chk["std_csv"]).abs().max())
print(f"\nConsistência raw x metrics.csv: maior diferença absoluta = {dif:.4f} ms")
print("\nConcluído. Figuras em:", OUT.resolve())
