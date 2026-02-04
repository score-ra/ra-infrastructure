// Selfwize Dashboard - Service Directory
(function() {
    fetch('services.json')
        .then(function(r) { return r.json(); })
        .then(function(data) {
            var grid = document.getElementById('services');
            data.services.forEach(function(svc) {
                var a = document.createElement('a');
                a.className = 'card';
                a.href = svc.url;
                a.target = '_blank';
                a.rel = 'noopener';
                a.innerHTML =
                    '<div class="icon">' + svc.icon + '</div>' +
                    '<div class="name"><span class="status"></span>' + svc.name + '</div>' +
                    '<div class="desc">' + svc.description + '</div>';
                grid.appendChild(a);
            });
        })
        .catch(function(err) {
            document.getElementById('services').textContent = 'Failed to load services: ' + err.message;
        });
})();
