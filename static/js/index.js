let socket = io();

let panel = document.getElementById('panel')
let log = document.getElementById('log')
let input = document.getElementById('input')
let openDrawer = document.getElementById('open-drawer')
let closeDrawer = document.getElementById('close-drawer')

socket.on('connect', () => {
	input.className = 'middle input'
	input.querySelector('input').disabled = false
	log.innerHTML = ''
})

socket.on('disconnect', () => {
	input.className = 'middle input error'
	input.querySelector('input').disabled = true
})

socket.on('stdout', (string) => {
	appendToLog(string, "stdout")
})

input.addEventListener('submit', function (e) {
	e.preventDefault()
	let input = e.target.querySelector('input')
	appendToLog(input.value, "stdin")
	socket.emit('stdin', input.value)
	input.value = ''
})

openDrawer.addEventListener('click', function () {
	panel.className = 'card'
})

closeDrawer.addEventListener('click', function () {
	panel.className = 'card hidden'
})

function appendToLog(string, className) {
	let element = document.createElement('div')
	element.className = className
	element.innerText = string
	log.append(element)
	log.scrollTop = log.scrollHeight;
}
