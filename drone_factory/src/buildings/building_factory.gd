class_name BuildingFactory
extends RefCounted

## Создание здания по идентификатору описания.
##
## Единственное место, где тип из данных превращается в класс поведения.
## Реестр и системы работают только с базовым Building и о наследниках не знают.


static func create(def_id: StringName) -> Building:
	if not BuildingDefs.exists(def_id):
		Log.error("BuildingFactory: неизвестное здание %s" % def_id)
		return null
	var building: Building = _instantiate(BuildingDefs.kind(def_id))
	return building


static func _instantiate(kind: int) -> Building:
	match kind:
		BuildingDefs.Kind.DRILL:
			return Drill.new()
		BuildingDefs.Kind.FURNACE:
			return Furnace.new()
		BuildingDefs.Kind.ASSEMBLER:
			return Assembler.new()
		BuildingDefs.Kind.WATER_PUMP:
			return WaterPump.new()
		BuildingDefs.Kind.BOILER:
			return Boiler.new()
		BuildingDefs.Kind.REACTOR:
			return NuclearReactor.new()
		BuildingDefs.Kind.BEACON:
			return Beacon.new()
		BuildingDefs.Kind.LAB:
			return Lab.new()
		BuildingDefs.Kind.DRONE_PORT:
			return DronePort.new()
		BuildingDefs.Kind.SOLAR:
			return SolarPanel.new()
		BuildingDefs.Kind.WIND:
			return WindTurbine.new()
		BuildingDefs.Kind.ACCUMULATOR:
			return Accumulator.new()
		_:
			# Склад, столб и порт — инертные конструкции: их поведение целиком
			# описывается инвентарём и участием в сетях.
			return Building.new()
