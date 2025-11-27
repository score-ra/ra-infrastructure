"""Tests for network models."""

from datetime import datetime, timezone
from uuid import uuid4

import pytest

from inventory.models.network import Network, NetworkCreate


class TestNetworkCreate:
    """Tests for NetworkCreate model."""

    def test_create_ethernet_network(self):
        """Test creating ethernet network."""
        network = NetworkCreate(
            name="Main LAN",
            network_type="ethernet",
            site_id=uuid4(),
            cidr="192.168.1.0/24",
            gateway_ip="192.168.1.1",
        )
        assert network.name == "Main LAN"
        assert network.network_type == "ethernet"
        assert network.cidr == "192.168.1.0/24"

    def test_create_wifi_network(self):
        """Test creating WiFi network."""
        network = NetworkCreate(
            name="Main WiFi",
            network_type="wifi",
            site_id=uuid4(),
            ssid="MyNetwork",
            frequency="5GHz",
            security_type="WPA3",
        )
        assert network.name == "Main WiFi"
        assert network.network_type == "wifi"
        assert network.ssid == "MyNetwork"

    def test_create_zwave_network(self):
        """Test creating Z-Wave network."""
        network = NetworkCreate(
            name="Z-Wave Network",
            network_type="zwave",
            site_id=uuid4(),
            channel=25,
        )
        assert network.name == "Z-Wave Network"
        assert network.network_type == "zwave"
        assert network.channel == 25

    def test_create_with_invalid_type(self):
        """Test that invalid network type raises error."""
        with pytest.raises(ValueError):
            NetworkCreate(name="Test", network_type="invalid", site_id=uuid4())

    def test_all_valid_network_types(self):
        """Test all valid network types."""
        site_id = uuid4()
        for network_type in [
            "ethernet",
            "wifi",
            "zwave",
            "zigbee",
            "bluetooth",
            "thread",
            "matter",
            "other",
        ]:
            network = NetworkCreate(
                name="Test", network_type=network_type, site_id=site_id
            )
            assert network.network_type == network_type

    def test_vlan_id_validation_valid(self):
        """Test valid VLAN ID."""
        network = NetworkCreate(
            name="Test",
            network_type="ethernet",
            site_id=uuid4(),
            vlan_id=100,
        )
        assert network.vlan_id == 100

    def test_vlan_id_validation_min(self):
        """Test minimum VLAN ID."""
        network = NetworkCreate(
            name="Test",
            network_type="ethernet",
            site_id=uuid4(),
            vlan_id=1,
        )
        assert network.vlan_id == 1

    def test_vlan_id_validation_max(self):
        """Test maximum VLAN ID."""
        network = NetworkCreate(
            name="Test",
            network_type="ethernet",
            site_id=uuid4(),
            vlan_id=4094,
        )
        assert network.vlan_id == 4094

    def test_vlan_id_validation_invalid_low(self):
        """Test that VLAN ID 0 raises error."""
        with pytest.raises(ValueError):
            NetworkCreate(
                name="Test",
                network_type="ethernet",
                site_id=uuid4(),
                vlan_id=0,
            )

    def test_vlan_id_validation_invalid_high(self):
        """Test that VLAN ID > 4094 raises error."""
        with pytest.raises(ValueError):
            NetworkCreate(
                name="Test",
                network_type="ethernet",
                site_id=uuid4(),
                vlan_id=5000,
            )


class TestNetwork:
    """Tests for Network model."""

    def test_full_network(self):
        """Test full network entity."""
        now = datetime.now(timezone.utc)
        network = Network(
            id=uuid4(),
            name="Test Network",
            slug="test-network",
            network_type="ethernet",
            site_id=uuid4(),
            is_active=True,
            is_primary=False,
            created_at=now,
            updated_at=now,
        )
        assert network.name == "Test Network"
        assert network.slug == "test-network"
