var express = require('express')
var app = require('express')();
var http = require('http').Server(app);
var io = require('socket.io')(http);
let spawn = require('child_process').spawn

const PORT = 3000 // Web page will be available on localhost:3000

// Dictionary of users (socket ids) to objects:
//   process: instance of our verilog program this user is using
let users = {}

app.use(express.static('static'));

app.get('/', function(req, res){
  res.sendFile(__dirname + '/index.html');
});

io.on('connection', function(socket){
  users[socket.id] = {
    process: getNewProcess(socket)
  }
  socket.on('stdin', function(string) {
    users[socket.id].process.stdin.write(string)
  })
  socket.on('disconnect', function() {
    delete users[socket.id]
  })
});

http.listen(PORT, function(){
  console.log('listening on *:' + PORT);
});

function getNewProcess(socket) {
  let childProcess = spawn(process.platform === 'win32' ? 'vvp a.out' : './a.out')
  // Create hook on our iverilog process that will receive every line of output from our iverilog program
  childProcess.stdout.on('data', (chunk) => {
    socket.emit('stdout', chunk.toString())
  })
  childProcess.stdout.on('close', (code) => {
    console.log('closed:' + code)
  })
  childProcess.stderr.on('data', (chunk) => {
    console.log('err:' + chunk)
  })
  return childProcess
}
