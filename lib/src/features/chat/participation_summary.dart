String participationSummaryText(int submitted, int? eligible) {
  if (eligible == null) return '已有 $submitted 人参与';
  if (submitted == eligible) return '全部 $eligible 人已参与';
  return '已参与 $submitted/$eligible 人';
}
