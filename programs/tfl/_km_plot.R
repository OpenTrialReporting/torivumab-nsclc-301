# torivumab guidelines loaded
# =============================================================================
# _km_plot.R
# Shared Kaplan-Meier plotting helper used by F-EFF-01 (OS) and F-EFF-02 (PFS).
# Renders the curve, median markers, HR annotation, and number-at-risk table
# as a single ggplot via patchwork.
# =============================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("patchwork", quietly = TRUE)) install.packages("patchwork")
  library(patchwork)
})

# Build the canonical KM figure for a two-arm comparison
# data       : data frame with columns AVAL_MO, CNSR (0=event,1=cens), arm (factor)
# endpoint   : e.g. "Overall Survival"
# max_month  : x-axis upper bound (also used for risk-table sequence)
# risk_breaks: numeric vector of months at which to compute n-at-risk
# output_id  : appears in the figure caption
km_plot <- function(data, endpoint, xlab, ylab, max_month, risk_breaks,
                    output_id = "") {
  ARM_COL <- c("Torivumab + Chemo" = "#1F3864",
               "Placebo + Chemo"   = "#C0392B")

  fit <- survfit(Surv(AVAL_MO, CNSR == 0) ~ arm, data = data,
                 conf.type = "log-log")

  # Extract the survival data manually so we can plot in pure ggplot
  s <- summary(fit, censored = TRUE)
  surv_df <- data.frame(
    time      = s$time,
    surv      = s$surv,
    n.censor  = s$n.censor,
    strata    = gsub("^arm=", "", as.character(s$strata)),
    stringsAsFactors = FALSE
  )
  surv_df$strata <- factor(surv_df$strata, levels = levels(data$arm))

  # Cox HR + log-rank p for annotation
  cox <- summary(coxph(Surv(AVAL_MO, CNSR == 0) ~ arm, data = data))
  hr  <- cox$conf.int[1, "exp(coef)"]
  lo  <- cox$conf.int[1, "lower .95"]
  hi  <- cox$conf.int[1, "upper .95"]
  sd  <- survdiff(Surv(AVAL_MO, CNSR == 0) ~ arm, data = data)
  p_lr <- 1 - pchisq(sd$chisq, df = length(sd$n) - 1)

  # Median per arm
  med_tbl <- summary(fit)$table
  med_trt <- med_tbl["arm=Torivumab + Chemo", "median"]
  med_pbo <- med_tbl["arm=Placebo + Chemo",   "median"]

  ann <- sprintf(
    "HR = %.3f (95%% CI %.3f, %.3f) | log-rank p %s\nMedian: TRT %.1fm,  PBO %.1fm",
    hr, lo, hi,
    ifelse(p_lr < 0.001, "<0.001", sprintf("= %.3f", p_lr)),
    med_trt, med_pbo
  )

  # ---- Main KM curve --------------------------------------------------
  p_main <- ggplot(surv_df, aes(x = time, y = surv, colour = strata)) +
    geom_step(linewidth = 1) +
    geom_point(data = subset(surv_df, n.censor > 0),
               aes(x = time, y = surv, colour = strata),
               shape = "|", size = 2.5, show.legend = FALSE) +
    geom_hline(yintercept = 0.5, linetype = "dashed",
               colour = "#888888", linewidth = 0.3) +
    scale_colour_manual(values = ARM_COL, name = NULL) +
    scale_x_continuous(name = xlab, breaks = risk_breaks,
                       limits = c(0, max_month), expand = c(0, 0)) +
    scale_y_continuous(name = ylab, limits = c(0, 1.02),
                       breaks = seq(0, 1, by = 0.2),
                       labels = percent_format(accuracy = 1)) +
    annotate("label",
             x = max_month * 0.55, y = 0.85, label = ann,
             hjust = 0, vjust = 0.5, size = 3.2, lineheight = 1.0,
             colour = "#1F3864", fill = "white",
             label.padding = unit(0.4, "lines"),
             label.r = unit(0.1, "lines")) +
    labs(
      title    = sprintf("%s — Kaplan-Meier Curve", endpoint),
      subtitle = "ITT Population — synthetic data",
      caption  = sprintf("%s  |  %s  |  Source: ADTTE  |  %s",
                         output_id, PROTOCOL, DRAFT_TAG)
    ) +
    theme_minimal(base_family = F_SANS, base_size = 11) +
    theme(
      plot.title       = element_text(face = "bold", colour = C_NAVY, size = 13),
      plot.subtitle    = element_text(colour = "#444444", size = 10),
      plot.caption     = element_text(colour = "#C0392B", size = 7,
                                       face = "italic", hjust = 0),
      legend.position  = "top",
      legend.text      = element_text(size = 10),
      panel.grid.minor = element_blank(),
      axis.title       = element_text(face = "bold", size = 10)
    )

  # ---- Number-at-risk table ------------------------------------------
  risk_df <- summary(fit, times = risk_breaks, extend = TRUE)
  risk_tbl <- data.frame(
    time     = risk_df$time,
    n_risk   = risk_df$n.risk,
    strata   = gsub("^arm=", "", as.character(risk_df$strata)),
    stringsAsFactors = FALSE
  )
  risk_tbl$strata <- factor(risk_tbl$strata, levels = levels(data$arm))

  p_risk <- ggplot(risk_tbl, aes(x = time, y = strata, label = n_risk)) +
    geom_text(aes(colour = strata), size = 3.2, family = F_SANS) +
    scale_x_continuous(breaks = risk_breaks, limits = c(0, max_month),
                       expand = c(0, 0), position = "top") +
    scale_y_discrete(limits = rev(levels(risk_tbl$strata))) +
    scale_colour_manual(values = ARM_COL, guide = "none") +
    labs(title = "Number at risk", x = NULL, y = NULL) +
    theme_minimal(base_family = F_SANS, base_size = 9) +
    theme(
      plot.title       = element_text(face = "bold", size = 9, colour = "#444444"),
      panel.grid       = element_blank(),
      axis.text.x      = element_blank(),
      axis.text.y      = element_text(face = "bold", size = 8.5),
      plot.margin      = margin(2, 5, 2, 5)
    )

  # Combine — KM on top, risk table below, sharing x-axis approximately
  p_main / p_risk + plot_layout(heights = c(5, 1))
}
