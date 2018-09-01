function Log-Error {
    param ($Message = $(throw "Message parameter for Log-Error is required"))
    write-host "Error occurred! $Message" -ForegroundColor Red
    exit
}

function Log-Warning {
    param ($Message = $(throw "Message parameter for Log-Warning is required"))
    write-host $Message -ForegroundColor Yellow
}
