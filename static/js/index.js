let socket = io();

let panel = document.getElementById('panel')
let log = document.getElementById('log')
let input = document.getElementById('input')
let toggleDrawer = document.getElementById('toggle-drawer')
let title = document.getElementById('title')
let hackerStart = document.getElementById('hacker-start')
let compTemplate = Handlebars.compile(document.getElementById('comp\_template').innerHTML)
let components

let hackerText = [
  	"Initializing...",
  	"Shining laser into space...",
  	"Transmitting byte code...",
  	"Analyzing results...",
  	"Transmitting hotfix...",
  	"Analyzing self...",
  	"Hijacking phone lines...",
  	"Starting background music...",
  	"Establishing connection...",
  	"Accessing mainframe...",
  	"Loading interface...",
	"Success!!"
]
let hackerLevel = 0
let hackerInterval

// Information on each component type
// including what they're called, their css and template class name,
// and a function for any component type specific handling while
// creating their component cards
let TYPES = {
	"00": {
		name: "Airflow Control Unit",
		class: "airflow",
		parse: () => {}
	},
	"01": {
		name: "Thrusters Control Unit",
		class: "thruster",
		parse: () => {}
	},
	"10": {
		name: "Solar Panel Control Unit",
		class: "solar",
		parse: (view, data) => {
			view.sun = data.slice(0, 1) === "0" ? "Sun is Blocked" : "Sun is Visible"
		}
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
			float1: parseFloat(values[2]).toString(),
			float2: parseFloat(values[3]).toString(),
			float3: parseFloat(values[4]).toString(),
			class: type.class,
			name: type.name
		}
		// Add component type specific values
		type.parse(view, values[5])

		components[values[0]] = {
			view: view,
			type: type,
			values: values[5]
		}

		// Render and display our component card
		document.body.insertAdjacentHTML('beforeend', compTemplate(view))
	},
	update: (values) => {
		let left = 226 - values[1]
		let right = left + parseInt(values[2])
		let comp = components[values[0]]

		comp.values = comp.values.substring(0, left) + 
					  values[3] + 
					  comp.values.substring(right)

		comp.type.parse(comp.view, comp.values)
		document.getElementById('comp ' + values[0]).outerHTML = compTemplate(comp.view)
	}
}

socket.on('connect', () => {
	// Disable Log
	input.className = 'middle input'
	title.className = 'title'
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
	title.className = 'title error'
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

title.addEventListener('click', function () {
	if (hackerLevel === 0) {
		hackerLevel++
		hackerInterval = setInterval(initiateHackerMode, 500)
		hackerStart.className = "hacker-start"
	}
})

function initiateHackerMode() {
	hackerStart.innerHTML += hackerText[hackerLevel - 1] + "<br/>"
	hackerLevel++
	if (hackerLevel == 9) {
		document.body.className = "hacker"
		document.body.insertAdjacentHTML('beforeend', '<iframe class="hacker-theme" src="http://www.youtube.com/embed/XAYhNHhxN0A?autoplay=1&loop=1&playlist=XAYhNHhxN0A" frameborder="0" allowfullscreen></iframe>​')
	}
	if (hackerLevel > hackerText.length) {
		clearInterval(hackerInterval)
		hackerStart.className += " hidden"
	}
}

function appendToLog(string, className) {
	let element = document.createElement('div')
	element.className = className
	element.innerText = string
	let setScroll = log.scrollHeight - log.scrollTop === log.clientHeight
	log.append(element)
	if (setScroll) log.scrollTop = log.scrollHeight;
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

// Functions to be called by templated DOM elements
function toggleOn(e) { // Toggles whether or not a fan is on
	let message = "WRITE_DATA " + e.getAttribute("component") + " 101 1 " + (e.text === "Turn On" ? "1" : "0")
	appendToLog(message, "stdin")
	socket.emit("stdin", message)
	// Example message for changing fan speed:
	// WRITE_DATA 000 100 2 00
	// BTW, the format is: COMMAND COMP_ID DATA_INDEX(left) DATA_WIDTH NEW_VALUE
}
