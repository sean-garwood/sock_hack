/**
 * Draw interface from which the user selects the wifi network to "connect" to.
 * @todo figure out what we're connecting to...
 */

function banner(a) {
  document.writeln(
    "<title>" +
      a +
      "</title></head><body><center><div id=status></div></center>"
  );
}

/**
 * Sets innerHTML of @param dst to @param src.
 */
function elem_set(dst, src) {
  document.getElementById(dst).innerHTML = src;
}

/** creates a new div and inserts a child with @param content */
function escapeHtml(content) {
  let b = document.createElement("div");
  b.appendChild(document.createTextNode(content));
  return b.innerHTML;
}

/** creates a div, sets its innerHTML to @param a sets its first child node.
 * @returns the value of the first child node if the child node exists, else an
 * empty string is returned.
 */
function unescapeHtml(a) {
  let c = document.createElement("div");
  c.innerHTML = a;
  let b = c.childNodes[0];
  return b ? b.nodeValue : "";
}

/** flashes a message */
function status_msg(c, b) {
  let a = "Cancel";
  if (b) {
    a = "Dismiss";
  }
  elem_set(
    "status",
    "<div id=flash_alert>" +
      c +
      '<p><button onclick="conn_cancel()">' +
      a +
      "</button></div>"
  );
  document.getElementById("status").scrollIntoView(true);
}

/** @param scanData get one row of the scan results */
function scan_td(scanData) {
  return "<td>" + scanData + "</td>";
}

function ssid_or_bssid(a) {
  if (a.bssid) {
    return "bssid=" + encodeURIComponent(a.bssid);
  }
  return "ssid=" + encodeURIComponent(a.ssid);
}

function wifi_spec_status_resp(d, b) {
  let c = window.scan_cur;
  let i;
  let g;
  let h;
  let a = 0;
  if (b !== 200) {
    return;
  }
  i = JSON.parse(d).wifi_status;
  try {
    g = i.connect_history[0];
    if (g.last == 1 && g.error == 0) {
      h = "Connection complete.";
      a = 1;
    } else {
      if (g.last == 1) {
        h = "Connection failed: " + g.msg + " (error " + g.error + ")";
        a = 1;
      } else {
        h = "In progress";
        if (i.state != null) {
          h += ": " + i.state;
        }
      }
    }
  } catch (f) {}
  status_msg("Connection to " + escapeHtml(c.ssid) + "<br>" + h, a);
  if (a == 1) {
    clearInterval(window.sts_intvl);
  }
  elem_set("div1", "");
  elem_set("div2", "");
}
/**
 * Desynchronize? @todo determine the purpose of this silly function
 *
 * @param httpRequestType One of the seven HTTP requests (GET, POST, etc.).
 * @param url The resource to send the request to.
 * @param delay Milliseconds to timeout.
 * @param res Callback function: can be
 *        {@link wifi_prof_resp} or
 *        {@link wifi_spec_status_resp} or
 *        {@link wifi_scan_rslt_resp} apparently.
 */
function send_async_req(httpRequestType, url, delay, res) {
  const req = new XMLHttpRequest();
  let finished = false;
  const wait = setTimeout(function () {
    finished = true;
    req.abort();
  }, delay);
  const done = 4; // readyState enum 4: DONE: The operation is complete.
  const isNotDone = () => req.readyState !== done;

  req.open(httpRequestType, url, true);
  req.onreadystatechange = function () {
    if (isNotDone()) {
      return; // keep going: return control to this.profiles().
    }
    if (finished) {
      return; // the request was aborted: keep going.
    }
    clearTimeout(wait); // else, stop waiting and...
    res(req.responseText, req.status); // ...resolve the request.
  };
  req.send(null); // send request to the server
}

/**
 * Creates an XHR, opens (@todo ?) and sends (@todo ?) null
 * @param httpMethod The HTTP method to use.
 * @param url the resource to send the reqest to
 * @param wifiStatusResponseCallback A callback to the {@link wifi_status_resp}.
 */
function send_sync_req(httpMethod, url, wifiStatusResponseCallback) {
  let xhr = new XMLHttpRequest();
  xhr.open(httpMethod, url, false);
  xhr.send(null); // send the xhr to the server. We have a server running on this thing?! Guess we have to.
  wifiStatusResponseCallback(xhr.responseText, xhr.status); // call wifi_status_resp
}

/**
 * Sets global wifi_status to the value of ...b?
 * @param data JSON data of some sort
 * @todo Figure out what the heck the json data is
 * @param _a Unused argument?
 */
function wifi_status_resp(data, _a) {
  // data is "{\"wifi_status\":{\"connect_history\":[{\"ssid_info\": \"cr\",\"ssid_len\":6,\"bssid\":\"c684\",\"error\":2,\"msg\":\"connection timed out\",\"mtime\":760,\"last\":0,\"ip_addr\":\"0.0.0.0\",\"netmask\":\"0.0.0.0\",\"default_route\":\"0.0.0.0\",\"dns_servers\":[\"0.0.0.0\",\"0.0.0.0\"]}],\"dsn\":\"AC000W025363194\",\"device_service\":\"SS3-Sleep-1a2039d9-device.aylanetworks.com\",\"log_service\":\"\",\"mac\":\"26:cd:8d:e2:99:3a\",\"mtime\":16740845,\"host_symname\":\"AC000W025363194\",\"connected_ssid\":\"\",\"ant\":1,\"rssi\":-200,\"bars\":0,\"state\":\"down\"}}"
  window.wifi_status = JSON.parse(data).wifi_status; // set the wifi status to data.wifi_status
}

/**
 * Get the available wifi networks.
 * @param statusFlag Determines whether to send a sync request.
 */
function wifi_status_get(statusFlag = 0) {
  let b = "wifi_status.json";
  let d = wifi_status_resp;
  if (statusFlag) {
    let a = window.scan_cur; // must be server-side.
    if (!a) {
      return;
    }
    b += "?" + ssid_or_bssid(a);
    d = wifi_spec_status_resp;
    send_async_req("GET", b, 1000, d);
    return;
  }
  send_sync_req("GET", b, d);
}

function wifi_connect_resp(b, a) {
  if (a >= 200 && a < 300) {
    window.sts_intvl = setInterval(wifi_status_get, 1000, 1);
    status_msg("Status unknown, please wait.<br>", 0);
  } else {
    let c = JSON.parse(b);
    if (c != null) {
      status_msg("Error: " + c.msg, 0);
    }
  }
}

function conn_start(c, a) {
  let b = "wifi_connect.json?" + ssid_or_bssid(a);
  // Looks like we're adding the password to the URL? Yikes.
  // oh and it's port 80, so no TLS. Double yikes.
  if (c != "") {
    // all good as long as c is not empty. Triple yikes.
    // let's say c == `${eval('some_malicious_code')}`
    // now we have a problem.
    b += "&key=" + encodeURIComponent(c);
  }
  // just POST it off to the server. What could go wrong?
  // Let me tell you what could go wrong: everything!
  // including but not limited to: eavesdropping
  // man-in-the-middle attacks
  // replay attacks
  // password leakage via referer headers
  // logging of URLs by intermediate proxies
  // arbitrary
  send_async_req("POST", b, 1000, wifi_connect_resp);
}

function conn_ok() {
  let a = window.scan_cur;
  try {
    let d = document.getElementById("ssid");
    if (d) {
      a.ssid = d.value;
    }
    let b = document.getElementById("key");
    if (b) {
      conn_start(b.value, a);
    }
  } catch (c) {
    console.error("caught " + c.message);
  }
  return false;
}

function conn_cancel() {
  window.scan_cur = null;
  elem_set("status", "");
  redraw();
}

function conn_prompt() {
  let a = window.scan_cur;
  let b = "<caption>Connect to network</caption><tr><td>Network<td>";
  if (a.ssid == "Join Other Network...") {
    b +=
      "<input id=ssid size=15 autocomplete=offautofocus autocapitalize=off autocorrect=offrequired>";
  } else {
    b += escapeHtml(a.ssid) + "<tr><td>Security<td>" + a.security;
  }
  b +=
    '<tr><td>Password<td><input type=password id=key size=15 required autocapitalize=off autocorrect=off><tr><td><td><button type=button onclick="conn_cancel()">Cancel</button>&nbsp;&nbsp;&nbsp;<button>Connect</button>';
  elem_set(
    "div1",
    '<form onSubmit="return conn_ok();"><table class=networks>' +
      b +
      "</table></form>"
  );
  elem_set("div2", "");
}

function connect(b) {
  let a = window.scan_results[b];
  window.scan_cur = a;
  if (a.security != "None") {
    conn_prompt();
  } else {
    conn_start("", a);
  }
}

function scan_connect(a) {
  return scan_td('<button onclick="connect(' + a + ')">Connect</button>');
}

function scan_line(b, a) {
  let d = "<tr>";
  d += scan_td(escapeHtml(a.ssid));
  d += "<td><table id=wifi_bars><tbody><tr>";
  for (let c = 0; c < a.bars; c++) {
    d += "<td width=20px>&nbsp;";
  }
  d += "</tbody></table></td>";
  if (a.type == "Ad hoc") {
    d += scan_td("ad-hoc");
  } else {
    if (a.type != "AP") {
      d += scan_td("-");
    } else {
      if (a.ssid == window.wifi_status.connected_ssid) {
        d += scan_td("Connected");
      } else {
        d += scan_connect(b);
      }
      if (a.security != "None" && a.security != "Unknown") {
        d += scan_td('<img alt=Secure src="lock.gif" style="height:0.92em;">');
      }
    }
  }
  d += "</tr>";
  return d;
}

/** render the wifi networks' refresh and buttons to connect */
function scan_tab() {
  let c = window.scan_results;
  let b =
    '<caption><h4>Select Wi-Fi Network<span id=refresh><image src=refresh.gif alt=Refresh style="height:0.92em;"onclick="rescan()"></span></h4></caption><thead><tr><th>Network</th><th>Strength</th><th class=conn_action></th></tr></thead><tbody>';
  for (let a = 0; a < c.length; a++) {
    b += scan_line(a, c[a]);
  }
  elem_set("div1", "<table class=networks>" + b + "</table>");
}

function wifi_scan_rslt_resp(b, a) {
  let d;
  try {
    d = JSON.parse(b).wifi_scan.results;
    d.sort(function (f, e) {
      if (e.type != "AP") {
        return f.signal;
      }
      if (f.type != "AP") {
        return -e.signal;
      }
      if (f.signal == e.signal && f.ssid != e.ssid) {
        return e.ssid < f.ssid ? 1 : -1;
      }
      return e.signal - f.signal;
    });
  } catch (c) {
    d = new Array();
  }
  d.push({
    ssid: "Join Other Network...",
    bars: 0,
    security: "Unknown",
    type: "AP",
  });
  window.scan_results = d;
  scan_tab();
}

/**
 * Calls `send_async_req`
 * @param _b Unused. Not sure why it's here.
 * @param _a Unused. Not sure why it's here.
 */
function scan(_b, _a) {
  send_async_req("GET", "wifi_scan_results.json", 1000, wifi_scan_rslt_resp);
}

function rescan() {
  send_async_req("POST", "wifi_scan.json", 1000, scan);
}

function prof_del_resp(b, a) {
  if (a < 299) {
    status_msg("Delete successful", 1);
  } else {
    status_msg("Delete failed", 1);
  }
  update();
}

function del_ok(c) {
  let b = unescapeHtml(c);
  let a = "wifi_profile.json?ssid=" + encodeURIComponent(b);
  send_async_req("DELETE", a, 1000, prof_del_resp);
}

function prof_delete(c) {
  let a = "<table><caption>Confirm ";
  let b = unescapeHtml(c);
  if (b == window.wifi_status.connected_ssid) {
    a += "disconnect and ";
  }
  a +=
    "delete of network " +
    c +
    '</caption><tr><td><button type=button onclick="redraw()">Cancel</button><td><button type=button onclick="del_ok(&quot;' +
    c +
    '&quot;)">OK</button></table>';
  elem_set("div1", a);
  elem_set("div2", "");
}

function prof_line(b) {
  let a;
  html = "<tr><td>" + escapeHtml(b.ssid) + "<td>";
  if (b.ssid == window.wifi_status.connected_ssid) {
    html += "Connected";
    a = "Disconnect";
  } else {
    a = "Delete";
  }
  return (
    html +
    '<td><button onclick="prof_delete(&quot;' +
    escapeHtml(b.ssid) +
    '&quot;)">' +
    a +
    "</button>"
  );
}

/**
 * render profiles, likely saved server side?
 */
function prof_tab(a) {
  let d = window.proftab; // just exists on window somehow.
  let c;
  c =
    "<table class=networks><caption><h4>Wi-Fi Profiles</h4></caption><thead><tr><th>Network<th>Status<th><th><tbody>";
  if (d != null) {
    d.sort(function (f, e) {
      if (e.ssid == f.ssid) {
        return 0;
      }
      return e.ssid < f.ssid ? 1 : -1;
    });
    for (let b = 0; b < d.length; b++) {
      c += prof_line(d[b]);
    }
  }
  c += "</table>";
  elem_set("div2", c);
}

function wifi_prof_resp(b, a) {
  window.proftab = JSON.parse(b).wifi_profiles;
  prof_tab();
}

function profiles() {
  send_async_req("GET", "wifi_profiles.json", 1000, wifi_prof_resp);
}

function redraw() {
  scan_tab();
  prof_tab();
}

function update() {
  profiles();
  scan();
}

wifi_status_get();
banner(window.wifi_status.host_symname + " Wifi Status");
document.writeln(
  "<section><div class=centered><br><div id=div1></div><br><br><div id=div2></div>"
);
update();
