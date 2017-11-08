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
		parse: (view, extra) => {
			view.room1 = extra.slice(0, 1) === "1" ? "active" : "inactive"
			view.room2 = extra.slice(1, 2) === "1" ? "active" : "inactive"
			view.room3 = extra.slice(2, 3) === "1" ? "active" : "inactive"
			view.room4 = extra.slice(3, 4) === "1" ? "active" : "inactive"
			view.alert = extra.slice(4, 5) === "1" ? " alert" : ""
		}
	},
	"01": {
		name: "Thrusters Control Unit",
		class: "thruster",
		parse: (view, extra) => {
			view.cw = extra.slice(0, 2) === "00" ? "active" : ""
			view.off = extra.slice(0, 2) === "01" ? "active" : ""
			view.ccw = extra.slice(0, 1) === "1" ? "active" : ""
		}
	},
	"10": {
		name: "Solar Panel Control Unit",
		class: "solar",
		parse: (view, extra) => {
			view.sun = extra.slice(0, 1)
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
	update_extra: (values) => {
		let left = 226 - values[1]
		let right = left + parseInt(values[2])
		let comp = components[values[0]]

		comp.values = comp.values.substring(0, left) + 
					  values[3].substring(left, right) + 
					  comp.values.substring(right)

		comp.type.parse(comp.view, comp.values)
		document.getElementById('comp ' + values[0]).outerHTML = compTemplate(comp.view)
	},
	update_float: (values) => {
		let comp = components[values[0]]
		switch(values[1]) {
			case "1":
				comp.view.float1 = values[2]
				break;
			case "2":
				comp.view.float2 = values[2]
				break;
			case "3":
				comp.view.float3 = values[2]
				break;
		}

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

// This is actually super important. I hope one day it won't be.
// Copied from my(Anthony) message on slack to the team:
/*
It turns out reading from stdin is blocking. The internet seems to disagree, and maybe its just iverilog that has this issue, but whenever I try to read from stdin it will wait until there's something to read, and not run other code in parallel- even in different modules. I tried to make it work for a long time, but at this point I think its a lost cause. So, I used a hack-y solution: I send a noop command every 250ms (this value can obviously be changed). What this means is that no matter what our clocks are in the verilog, if it takes less than 250ms to perform, its really going to be going off that instead
So effectively all our clocks will be on the same interval. Keep that in mind. Sorry for the inconvenience (and use counters to make clocks take longer, that's what I'll be doing with the solar panel bit anyways)
*/
setInterval(() => {
	appendToLog("t", "stdin")
	socket.emit("stdin", "t");
}, 250)

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
	let value = components[component].values.slice(index, index + 1) === "1" ? "0" : "1"
	let message = "e " + component + " " + (226 - index) + " 1 " + value
	appendToLog(message, "stdin")
	socket.emit("stdin", message)
}

function setState(e) { // Sets a state
	let component = e.getAttribute("component")
	let index = e.getAttribute("index")
	let width = e.getAttribute("width")
	let value = e.getAttribute("value")
	let message = "e " + component + " " + (226 - index) + " " + width + " " + value
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
