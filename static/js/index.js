let socket = io();

let panel = document.getElementById('panel')
let log = document.getElementById('log')
let input = document.getElementById('input')
let toggleDrawer = document.getElementById('toggle-drawer')
let compTemplate = Handlebars.compile(document.getElementById('comp\_template').innerHTML)
let components

let FAN_SPEEDS = {
	"00": "Extra Low",
	"01": "Low",
	"10": "Medium",
	"11": "High"
}

// Information on each component type
// including what they're called, their css and template class name,
// and a function for any component type specific handling while
// creating their component cards
let TYPES = {
	"000": {
		name: "Fan",
		class: "fan",
		parse: (view, data) => {
			view.on = data.slice(0, 1) === "0" ? "Turn On" : "Turn Off"
			view.currSpeed = data.slice(0, 1) === "0" ? "OFF" : FAN_SPEEDS[data.slice(1, 3)]
		}
	},
	"001": {
		name: "Boiler",
		class: "boiler",
		parse: () => {}
	},
	"010": {
		name: "Sensor",
		class: "sensor",
		parse: () => {}
	},
	"011": {
		name: "AC Unit",
		class: "ac",
		parse: () => {}
	},
	"100": {
		name: "Condenser",
		class: "condenser",
		parse: () => {}
	}
}

// Create our templates for each component type
let keys = Object.keys(TYPES)
for (let i = 0; i < keys.length; i++) {
	let template = TYPES[keys[i]].class
	Handlebars.registerPartial(
		template, 
		document.getElementById(template + '_template').innerHTML
	)	
}

// Dictionary of functions that get called when sent messages from the server
let actions = {
	init: (values) => {
		// Construct our view - all the parameters for this component
		let type = TYPES[values[1]]
		let view = {
			id: values[0],
			class: type.class,
			temperature: parseFloat(values[2]).toString(),
			name: values.slice(4).join(' ')
		}
		// Add component type specific values
		type.parse(view, values[3])

		components[values[0]] = {
			view: view,
			type: type,
			values: values[3]
		}

		// Render and display our component card
		document.body.insertAdjacentHTML('beforeend', compTemplate(view))
	},
	update: (values) => {
		let left = 101 - values[1]
		let right = left + parseInt(values[2])
		let comp = components[values[0]]
		comp.values = comp.values.substring(0, left) + 
					  values[3].substring(32 - values[2]) + 
					  comp.values.substring(right)

		comp.type.parse(comp.view, comp.values)
		document.getElementById('comp ' + values[0]).outerHTML = compTemplate(comp.view)
	}
}

socket.on('connect', () => {
	// Disable Log
	input.className = 'middle input'
	input.querySelector('input').disabled = false

	// Clear Log
	log.innerHTML = ''

	// Clear fans list
	let elements = document.getElementsByClassName('comp')
	while (elements[0])
		elements[0].parentNode.removeChild(elements[0])
	components = {}
})

socket.on('disconnect', () => {
	input.className = 'middle input error'
	input.querySelector('input').disabled = true
})

socket.on('stdout', (string) => {
	appendToLog(string, "stdout")
	let values = string.trim().split(/\s+/)
	if (actions[values[0]]) actions[values[0]](values.slice(1))
	else console.log(values)
})

input.addEventListener('submit', function (e) {
	e.preventDefault()
	let input = e.target.querySelector('input')
	appendToLog(input.value, "stdin")
	socket.emit('stdin', input.value)
	input.value = ''
})

toggleDrawer.addEventListener('click', function () {
	panel.className = panel.className === 'panel' ? 'panel hidden' : 'panel'
})

function appendToLog(string, className) {
	let element = document.createElement('div')
	element.className = className
	element.innerText = string
	log.append(element)
	log.scrollTop = log.scrollHeight;
}

// Functions to be called by templated DOM elements
function toggleOn(e) { // Toggles whether or not a fan is on
	let message = "WRITE_DATA " + e.getAttribute("component") + " 101 1 " + (e.text === "Turn On" ? "1" : "0")
	appendToLog(message, "stdin")
	socket.emit("stdin", message)
	// Example message for changing fan speed:
	// WRITE_DATA 000 100 2 00
	// BTW, the format is: COMMAND COMP_ID DATA_INDEX(left) DATA_WIDTH NEW_VALUE
}
