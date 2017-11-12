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
  	"Acquiring Sentience...",
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
		parse: (view, data) => {
			view.oxygen = data[0]
			view.room1 = data[1] === "1" ? "active" : "inactive"
			view.room2 = data[2] === "1" ? "active" : "inactive"
			view.room3 = data[3] === "1" ? "active" : "inactive"
			view.room4 = data[4] === "1" ? "active" : "inactive"
			view.alert = data[5] === "1" ? " alert" : ""
		},
		update: (comp, data) => {
			comp.type.parse(comp.view, data)
			comp.values = data
		}
	},
	"01": {
		name: "Thrusters Control Unit",
		class: "thruster",
		parse: (view, data) => {
			view.angle = parseFloat(data[0].slice(0, 4))
			view.velocity = parseFloat(data[1])
			view.thrust = parseFloat(data[2])
			let direction = data[3]
			view.cw = direction === "00" ? "active" : ""
			view.off = direction === "01" ? "active" : ""
			view.ccw = direction.slice(0,1) === "1" ? "active" : ""
		},
		update: (comp, data) => {
			comp.type.parse(comp.view, data)
			comp.values = data
		}
	},
	"10": {
		name: "Solar Panel Control Unit",
		class: "solar",
		parse: (view, data) => {
			view.angle = parseFloat(data[0].slice(0, 4))
			view.power = parseFloat(data[1])
			let sun = data[2]
			view.sun = sun.slice(0, 1)
			view.time = 16 - parseInt(sun.slice(1, 5), 2)
		},
		update: (comp, data) => {
			let angle = comp.view.angle
			comp.type.parse(comp.view, data)
			comp.view.angle = angle
			setTimeout(() => {
				document.getElementById("arrow " + comp.view.id).style.transform = 'scaleY(-1) rotate(' + data[0] + 'rad)'
				document.getElementById("angle " + comp.view.id).innerText = 'Current Solar Panel Angle: ' + data[0].slice(0, 4) + ' radians'
				comp.view.angle = data[0].slice(0, 4)
			}, 10)
			comp.values = data
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
		let type = TYPES[values[0]]
		let view = {
			id: values[0],
			class: type.class,
			name: type.name
		}
		// Add component type specific values
		type.parse(view, values.slice(1))

		components[values[0]] = {
			view: view,
			type: type,
			values: values.slice(1)
		}

		// Render and display our component card
		document.body.insertAdjacentHTML('beforeend', compTemplate(view))
	},
	update: (values) => {
		let comp = components[values[0]]
		comp.type.update(comp, values.slice(1))
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

// This is actually super important. I hope one day it won't be.
// Copied from my(Anthony) message on slack to the team:
/*
It turns out reading from stdin is blocking. The internet seems to disagree, and maybe its just iverilog that has this issue, but whenever I try to read from stdin it will wait until there's something to read, and not run other code in parallel- even in different modules. I tried to make it work for a long time, but at this point I think its a lost cause. So, I used a hack-y solution: I send a noop command every 250ms (this value can obviously be changed). What this means is that no matter what our clocks are in the verilog, if it takes less than 250ms to perform, its really going to be going off that instead
So effectively all our clocks will be on the same interval. Keep that in mind. Sorry for the inconvenience (and use counters to make clocks take longer, that's what I'll be doing with the solar panel bit anyways)
*/
setInterval(() => {
	appendToLog("t", "stdin")
	socket.emit("stdin", "t");
}, 500)

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
		socket.emit("stdin", "h")
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
function toggleBool(e) { // Toggles a boolean
	let component = e.getAttribute("component")
	let index = parseInt(e.getAttribute("index"))
	let value = components[component].values[index] === "1" ? "0" : "1"
	let message = "b " + component + " " + index + " " + value
	appendToLog(message, "stdin")
	socket.emit("stdin", message)
}

function setState(e) { // Sets a state
	let component = e.getAttribute("component")
	let index = e.getAttribute("index")
	let value = e.getAttribute("value")
	let message = "b " + component + " " + index + " " + value
	appendToLog(message, "stdin")
	socket.emit("stdin", message)
}

function setFloat(e) { // Sets a float
	let component = e.getAttribute("component")
	let index = e.getAttribute("index")
	let message = "f " + component + " " + index + " " + e.value
	appendToLog(message, "stdin")
	socket.emit("stdin", message)
}
