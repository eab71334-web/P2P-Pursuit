extends SceneTree
# usage: godot --headless -s tools/stage_audit.gd  -> designs many stages and audits them
func _init():
	var bad := 0
	var total := 0
	var br := 0
	for s in range(1, 81):
		var st := Track.design_stage(s * 7717)
		var t := Track.from_stage(st)
		var probs := t.audit()
		var t2 := Track.from_stage(st)
		if t2.points.size() != t.points.size() or t2.branches.size() != t.branches.size() or t2.tunnels != t.tunnels:
			probs.append("NOT DETERMINISTIC")
		total += 1
		br += t.branches.size()
		if not probs.is_empty():
			bad += 1
			print("BAD seed ", s, " ", st["theme"], " ", probs)
	print("AUDIT stages=", total, " bad=", bad, " avg_branches=", float(br) / total)
	quit()
