var Color= new Array();
Color[1] = "ff";
Color[2] = "ee";
Color[3] = "dd";
Color[4] = "cc";
Color[5] = "bb";
Color[6] = "aa";
Color[7] = "99";

function waittofade() {
    setTimeout("fadeIn(7)", 1000);
}

function fadeIn(where) {
    if (where >= 1) {
        document.getElementById('fade').style.backgroundColor = "#ffff" + Color[where];
        where -= 1;
        setTimeout("fadeIn("+where+")", 200);
    }
}

function validateField(fieldId, alertMessage) {
    if (document.getElementById(fieldId).value == "") {
        alert(alertMessage);
        document.getElementById(fieldId).focus();
        return false;
    } else {
        return true;
    }
}

function popup(url,width,height) {
        window.open(url,'popup','width='+width+',height='+height+',scroolbars=auto,resizable=yes,toolbar=no,directories=no,menubar=no,status=no,left=100,top=100');
        return false;
}
