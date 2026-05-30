
--[=[
	Stack of values that allows multiple systems to enable or disable a state.

	```lua
	local disabledStack = maid:Add(StateStack.new(false, "boolean"))
	print(disabledStack:GetState()) --> false

	maid:GiveTask(disabledStack.Changed:Connect(function()
		print("From changed event we have state: ", disabledStack:GetState())
	end))

	local cancel = disabledStack:PushState(true) --> From changed event we have state: true
	print(disabledStack:GetState()) --> true

	cancel()  --> From changed event we have state: true
	print(disabledStack:GetState()) --> false

	disabledStack:Destroy()
	```

	@class StateStack
]=]

const BaseObject = require('./roblox_packages/BaseObject')
const ValueObject = require('./roblox_packages/ValueObject')

-- selene: allow(unused_variable)
const Brio = require('./roblox_packages/Brio')
const Observable = require('./roblox_packages/Observable')
const Rx = require('./roblox_packages/Rx')
const Signal = require('./roblox_packages/Signal')

const StateStack = setmetatable({}, BaseObject)
StateStack.ClassName = 'StateStack'
StateStack.__index = StateStack

export type StateStack<T> =
	typeof(setmetatable(
		{} :: {
			Changed: Signal.Signal<T>,

			_state: ValueObject.ValueObject<T>,
			_defaultValue: T,
			_stateStack: { { T } },
		},
		{} :: typeof({ __index = StateStack })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new StateStack.
	@param defaultValue any -- The default value to use for the statestack.
	@param checkType string?
	@return StateStack
]=]
@checked
function StateStack.new<T>(defaultValue: T, checkType: ValueObject.ValueObjectTypeArg?): StateStack<T>
	local self = setmetatable(BaseObject.new() :: any, StateStack)

	self._state = self._maid:Add(ValueObject.new(defaultValue, checkType))
	self._defaultValue = defaultValue
	self._stateStack = {}

	--[=[
	Fires with the new state
	@prop Changed Signal<T>
	@within StateStack
]=]
	self.Changed = self._state.Changed

	return self :: StateStack<T>
end

--[=[
	Gets the count of the stack
	@return number
]=]
@checked
function StateStack.GetCount<T>(self: StateStack<T>): number
	return #self._stateStack
end

--[=[
	Gets the current state
	@return T
]=]
@checked
function StateStack.GetState<T>(self: StateStack<T>): T
	return self._state.Value
end

--[=[
	Observes the current value of stack
	@return Observable<T>
]=]
@checked
function StateStack.Observe<T>(self: StateStack<T>): Observable.Observable<T>
	return self._state:Observe()
end

--[=[
	Observes the current value of stack
	@param predicate function
	@return Observable<T>
]=]
@checked
function StateStack.ObserveBrio<T>(self: StateStack<T>, predicate: Rx.Predicate<T>?): Observable.Observable<Brio.Brio<T>>
	return self._state:ObserveBrio(predicate) :: any
end

--[=[
	Pushes the current state onto the stack
	@param state T
	@return function -- Cleanup function to invoke
]=]
@checked
function StateStack.PushState<T>(self: StateStack<T>, state: T): () -> ()
	local data: { T } = { state }
	table.insert(self._stateStack, data)
	self:_updateState()

	return function()
		if self.Destroy then
			self:_popState(data)
		end
	end
end

--[=[
	Pushes the brio's content onto the stack for the lifetime of the brio

	@param brio Brio
	@return function -- Cleanup function
]=]
@checked
function StateStack.PushBrio<T>(self: StateStack<T>, brio: Brio.Brio<T>): (() -> ())?
	if brio:IsDead() then
		return nil
	end

	local maid, state = brio:ToMaidAndValue()
	maid:GiveTask(self:PushState(state))

	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	self._maid[maid] = maid

	return function()
		self._maid[maid] = nil
	end
end

@checked
function StateStack._popState<T>(self: StateStack<T>, data: { T })
	local index = table.find(self._stateStack, data)
	if index then
		table.remove(self._stateStack, index)
		self:_updateState()
	else
		warn('[StateStack] - Failed to find index')
	end
end

@checked
function StateStack._updateState<T>(self: StateStack<T>)
	local dataContainer = self._stateStack[#self._stateStack]
	if dataContainer == nil then
		self._state.Value = self._defaultValue
	else
		self._state.Value = dataContainer[1]
	end
end

--[=[
	Cleans up the StateStack and sets the metatable to nil.

	:::tip
	Be sure to call this to clean up the state stack!
	:::
	@method Destroy
	@within StateStack
]=]


StateStack.RxStateStackUtils = require('./RxStateStackUtils')

return StateStack
