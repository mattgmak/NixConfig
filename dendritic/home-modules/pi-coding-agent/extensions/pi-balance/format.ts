/**
 * Text layout for /balanced-usage and /balanced-route.
 *
 * Every provider row uses the same cell width, so the three windows line up in
 * columns. Window names follow the common set in quota.ts: 5-hour, weekly,
 * monthly.
 */

import type { QuotaWindow, WindowKind } from "./quota.ts";

const LABEL_WIDTH = 2;
const PERCENT_WIDTH = 4;
const BAR_WIDTH = 8;
const PROVIDER_WIDTH = 11;
const MAX_LINE = 74;

const CELL_ORDER: readonly WindowKind[] = ["five_hour", "weekly", "monthly"];
const CELL_LABELS: Record<WindowKind, string> = {
  five_hour: "5h",
  weekly: "w",
  monthly: "m",
};

/** One provider row of the /balanced-usage table. */
export interface UsageRow {
  /** Provider name, padded to PROVIDER_WIDTH. */
  label: string;
  windows: QuotaWindow[];
  /** Rank in the failover order. Omitted for a closed route. */
  rank?: number;
  /** Trailing text: `pick`, `in use`, `closed 9m`, leftover credits. */
  tail?: string;
}

/** Everything /balanced-route shows. */
export interface RouteView {
  title: string;
  /** Routed provider and model, or `none · every route closed`. */
  routed: string;
  /** When and why the route was set. Omit when no route exists. */
  set?: string;
  /** Failover order entries, e.g. `1 opencode-go 21.0%`. */
  order: readonly string[];
}

function bar(percent: number): string {
  const clamped = Math.min(100, Math.max(0, percent));
  const filled = clamped > 0 ? Math.max(1, Math.round((clamped / 100) * BAR_WIDTH)) : 0;
  return "█".repeat(filled) + "░".repeat(BAR_WIDTH - filled);
}

function percentText(percent: number): string {
  return `${Math.round(Math.min(100, Math.max(0, percent)))}%`;
}

/** One 16-character cell: `5h 31% ██░░░░░░`. */
function cell(kind: WindowKind, window: QuotaWindow | undefined): string {
  const label = CELL_LABELS[kind].padStart(LABEL_WIDTH);
  const percent = window ? percentText(window.percent) : "--";
  const blocks = window ? bar(window.percent) : "░".repeat(BAR_WIDTH);
  return `${label} ${percent.padStart(PERCENT_WIDTH)} ${blocks}`;
}

function renderRow(row: UsageRow): string {
  const cells = CELL_ORDER.map((kind) =>
    cell(kind, row.windows.find((window) => window.kind === kind)),
  );
  const line = [row.label.padEnd(PROVIDER_WIDTH), ...cells].join(" ").trimEnd();
  const suffix = [row.rank === undefined ? undefined : `#${row.rank}`, row.tail]
    .filter((part) => part !== undefined)
    .join(" ");
  return suffix ? `${line}  ${suffix}` : line;
}

/** Wrap the failover order to MAX_LINE columns, indented past the label. */
function wrapOrder(order: readonly string[]): string[] {
  const indent = "        ";
  const lines: string[] = [];
  let line = "Order  ";
  for (const entry of order) {
    if (line !== "Order  " && line !== indent && `${line}  ${entry}`.length > MAX_LINE) {
      lines.push(line);
      line = indent;
    }
    line = line.endsWith("  ") ? `${line}${entry}` : `${line}  ${entry}`;
  }
  lines.push(line);
  return lines;
}

/** Format the /balanced-usage body. */
export function formatUsage(header: readonly string[], rows: readonly UsageRow[]): string {
  return [...header, "", ...rows.map(renderRow)].join("\n");
}

/** Format the /balanced-route body. */
export function formatRoute(view: RouteView): string {
  const lines = [view.title, `Routed  ${view.routed}`];
  if (view.set) lines.push(`Set     ${view.set}`);
  if (view.order.length > 0) lines.push(...wrapOrder(view.order));
  return lines.join("\n");
}
