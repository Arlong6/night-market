## RRPhysics — pure impact math for 橫衝直撞.
class_name RRPhysics
extends RefCounted

## Impact force from a moving body: linear in speed and mass.
static func impact_force(speed: float, mass: float) -> float:
	return absf(speed) * mass

## Does an impact of `force` break an object whose break threshold is `threshold`?
static func breaks_at(force: float, threshold: float) -> bool:
	return force >= threshold
