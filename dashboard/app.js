/**
 * Selfwize Dashboard
 * Config-driven service launcher with mobile-first design
 */

(function() {
    'use strict';

    // --------------------------------------------------------------------------
    // Configuration
    // --------------------------------------------------------------------------
    const CONFIG = {
        servicesUrl: 'services.json',
        statusCheckInterval: 60000, // 1 minute
        statusTimeout: 5000,        // 5 seconds
    };

    // --------------------------------------------------------------------------
    // Icon mapping (emoji-based for simplicity, no external deps)
    // --------------------------------------------------------------------------
    const ICONS = {
        // Home Automation
        'home': '🏠',
        'camera': '📹',
        'security': '🔒',
        'light': '💡',

        // Personal
        'health': '❤️',
        'inventory': '📦',
        'fitness': '💪',
        'family': '👨‍👩‍👧‍👦',
        'calendar': '📅',
        'notes': '📝',
        'data': '📊',

        // Infrastructure
        'database': '🗄️',
        'server': '🖥️',
        'network': '🌐',
        'monitor': '📈',
        'proxy': '🔀',
        'status': '✅',
        'admin': '⚙️',

        // Default
        'default': '🔗'
    };

    // --------------------------------------------------------------------------
    // SVG Icons
    // --------------------------------------------------------------------------
    const SVG_CHEVRON = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>`;

    // --------------------------------------------------------------------------
    // State
    // --------------------------------------------------------------------------
    let servicesData = null;
    let collapsedGroups = JSON.parse(localStorage.getItem('collapsedGroups') || '{}');

    // --------------------------------------------------------------------------
    // DOM Elements
    // --------------------------------------------------------------------------
    const container = document.getElementById('services-container');
    const lastUpdated = document.getElementById('last-updated');
    const connectionStatus = document.getElementById('connection-status');

    // --------------------------------------------------------------------------
    // Utilities
    // --------------------------------------------------------------------------
    function getIcon(iconKey) {
        return ICONS[iconKey] || ICONS['default'];
    }

    function formatTime(date) {
        return date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // --------------------------------------------------------------------------
    // Rendering
    // --------------------------------------------------------------------------
    function renderLoading() {
        container.innerHTML = `
            <div class="loading">
                <div class="loading-spinner"></div>
                <span class="loading-text">Loading services...</span>
            </div>
        `;
    }

    function renderError(message) {
        container.innerHTML = `
            <div class="error">
                <div class="error-icon">⚠️</div>
                <p class="error-message">${escapeHtml(message)}</p>
            </div>
        `;
    }

    function renderServiceCard(service) {
        const icon = getIcon(service.icon);
        const colorClass = service.color ? `service-icon--${service.color}` : 'service-icon--blue';
        const statusClass = service.status ? `service-status--${service.status}` : '';

        return `
            <a href="${escapeHtml(service.url)}"
               class="service-card"
               target="_blank"
               rel="noopener noreferrer"
               title="${escapeHtml(service.name)}${service.description ? ' - ' + escapeHtml(service.description) : ''}">
                <div class="service-icon ${colorClass}">
                    ${icon}
                    ${statusClass ? `<span class="service-status ${statusClass}"></span>` : ''}
                </div>
                <span class="service-name">${escapeHtml(service.name)}</span>
            </a>
        `;
    }

    function renderGroup(group) {
        const isCollapsed = collapsedGroups[group.id] === true;
        const collapsedClass = isCollapsed ? 'collapsed' : '';
        const groupIcon = getIcon(group.icon);

        const servicesHtml = group.services
            .map(service => renderServiceCard(service))
            .join('');

        return `
            <section class="service-group ${collapsedClass}" data-group-id="${escapeHtml(group.id)}">
                <header class="group-header" role="button" tabindex="0" aria-expanded="${!isCollapsed}">
                    <div class="group-title-wrapper">
                        <span class="group-icon">${groupIcon}</span>
                        <h2 class="group-title">${escapeHtml(group.name)}</h2>
                        <span class="group-count">${group.services.length}</span>
                    </div>
                    <span class="group-toggle">${SVG_CHEVRON}</span>
                </header>
                <div class="group-content">
                    ${servicesHtml}
                </div>
            </section>
        `;
    }

    function renderDashboard(data) {
        if (!data || !data.groups || data.groups.length === 0) {
            renderError('No services configured');
            return;
        }

        const groupsHtml = data.groups
            .map(group => renderGroup(group))
            .join('');

        container.innerHTML = groupsHtml;

        // Attach event listeners for collapsible sections
        attachGroupListeners();

        // Update timestamp
        lastUpdated.textContent = formatTime(new Date());
    }

    // --------------------------------------------------------------------------
    // Event Handlers
    // --------------------------------------------------------------------------
    function attachGroupListeners() {
        const headers = container.querySelectorAll('.group-header');

        headers.forEach(header => {
            header.addEventListener('click', handleGroupToggle);
            header.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    handleGroupToggle(e);
                }
            });
        });
    }

    function handleGroupToggle(e) {
        const header = e.currentTarget;
        const group = header.closest('.service-group');
        const groupId = group.dataset.groupId;

        group.classList.toggle('collapsed');

        const isCollapsed = group.classList.contains('collapsed');
        header.setAttribute('aria-expanded', !isCollapsed);

        // Persist state
        collapsedGroups[groupId] = isCollapsed;
        localStorage.setItem('collapsedGroups', JSON.stringify(collapsedGroups));
    }

    // --------------------------------------------------------------------------
    // Data Loading
    // --------------------------------------------------------------------------
    async function loadServices() {
        try {
            const response = await fetch(CONFIG.servicesUrl, {
                cache: 'no-cache'
            });

            if (!response.ok) {
                throw new Error(`Failed to load services: ${response.status}`);
            }

            servicesData = await response.json();
            renderDashboard(servicesData);
            updateConnectionStatus(true);

        } catch (error) {
            console.error('Error loading services:', error);
            renderError(`Unable to load services. ${error.message}`);
            updateConnectionStatus(false);
        }
    }

    function updateConnectionStatus(online) {
        const dot = connectionStatus.querySelector('.status-dot');
        const text = connectionStatus.querySelector('.status-text');

        if (online) {
            dot.className = 'status-dot status-dot--online';
            text.textContent = 'Online';
        } else {
            dot.className = 'status-dot';
            text.textContent = 'Offline';
        }
    }

    // --------------------------------------------------------------------------
    // Optional: Status Checking (can be enabled if needed)
    // --------------------------------------------------------------------------
    async function checkServiceStatus(url) {
        try {
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), CONFIG.statusTimeout);

            const response = await fetch(url, {
                method: 'HEAD',
                mode: 'no-cors',
                signal: controller.signal
            });

            clearTimeout(timeoutId);
            return 'online';
        } catch (error) {
            return 'offline';
        }
    }

    // --------------------------------------------------------------------------
    // Initialization
    // --------------------------------------------------------------------------
    function init() {
        renderLoading();
        loadServices();

        // Reload on visibility change (when user returns to tab)
        document.addEventListener('visibilitychange', () => {
            if (document.visibilityState === 'visible') {
                loadServices();
            }
        });
    }

    // Start
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
