let socket = io();

let panel = document.getElementById('panel')
let log = document.getElementById('log')
let input = document.getElementById('input')
let toggleDrawer = document.getElementById('toggle-drawer')
let compTemplate = Handlebars.compile(document.getElementById('comp\_template').innerHTML)

// Information on each component type
// including what they're called, their css and template class name,
// and a function for any component type specific handling while
// creating their component cards
let types = {
	"000": {
		name: "Fan",
		class: "fan",
		values: [
			"currTemp",
			"currSpeed"
		],
		parse: (view) => {
			let speeds = {
				"000": "Off",
				"001": "Extra Low",
				"010": "Low",
				"011": "Medium",
				"100": "High"
			}
			view.on = view.currSpeed === '000' ? "Turn On" : "Turn Off"
			view.currSpeed = speeds[view.currSpeed]
		}
	},
	"001": {
		name: "Boiler",
		class: "boiler",
		values: [
			"currTemp"
		],
		parse: (view) => {}
	},
	"010": {
		name: "Sensor",
		class: "sensor",
		values: [
			"currTemp"
		],
		parse: (view) => {}
	},
	"011": {
		name: "AC Unit",
		class: "ac",
		values: [
			"currTemp"
		],
		parse: (view) => {}
	},
	"100": {
		name: "Condenser",
		class: "condenser",
		values: [
			"currTemp"
		],
		parse: (view) => {}
	}
}

// Create our templates for each component type
let keys = Object.keys(types)
for (let i = 0; i < keys.length; i++) {
	let template = types[keys[i]].class
	Handlebars.registerPartial(
		template, 
		document.getElementById(template + '_template').innerHTML
	)	
}

// Dictionary of functions that get called when sent messages from the server
let actions = {
	init: (values) => {
		// Construct our view - all the parameters for this component
		let type = types[values[1]]
		let view = {
			id: values[0],
			name: values.slice(2 + type.values.length).join(' '),
			class: type.class
		}
		// Add component type specific values
		for (let i = 0; i < type.values.length; i++) {
			view[type.values[i]] = values[2 + i]
		}
		// Any component type specific view handling
		type.parse(view)

		// Render and display our component card
		document.body.insertAdjacentHTML('beforeend', compTemplate(view))
	}
}

socket.on('connect', () => {
	// Disable Log
	input.className = 'middle input'
	input.querySelector('input').disabled = false

	// Clear Log
	log.innerHTML = ''

	// Clear fans list
	let elements = document.getElementsByClassName('fan')
	while (elements[0])
		elements[0].parentNode.removeChild(elements[0])
})

socket.on('disconnect', () => {
	input.className = 'middle input error'
	input.querySelector('input').disabled = true
})

socket.on('stdout', (string) => {
	appendToLog(string, "stdout")
	let values = string.trim().split(/\s+/)
	actions[values[0]](values.slice(1))
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
