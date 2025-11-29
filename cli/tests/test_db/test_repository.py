"""Tests for base repository."""

from inventory.db.repository import BaseRepository


class TestSlugGeneration:
    """Tests for slug generation."""

    def test_simple_name(self):
        """Test slug from simple name."""
        assert BaseRepository.generate_slug("Test") == "test"

    def test_name_with_spaces(self):
        """Test slug from name with spaces."""
        assert BaseRepository.generate_slug("Test Name") == "test-name"

    def test_name_with_multiple_spaces(self):
        """Test slug from name with multiple spaces."""
        assert BaseRepository.generate_slug("Test   Name") == "test-name"

    def test_name_with_special_chars(self):
        """Test slug from name with special characters."""
        assert BaseRepository.generate_slug("Test@Name!") == "test-name"

    def test_name_with_numbers(self):
        """Test slug from name with numbers."""
        assert BaseRepository.generate_slug("Test 123") == "test-123"

    def test_name_with_leading_trailing_special(self):
        """Test slug strips leading/trailing special chars."""
        assert BaseRepository.generate_slug("!Test Name!") == "test-name"

    def test_uppercase_name(self):
        """Test slug normalizes to lowercase."""
        assert BaseRepository.generate_slug("TEST NAME") == "test-name"

    def test_mixed_case_name(self):
        """Test slug from mixed case name."""
        assert BaseRepository.generate_slug("TeSt NaMe") == "test-name"

    def test_hyphenated_name(self):
        """Test slug from already hyphenated name."""
        assert BaseRepository.generate_slug("test-name") == "test-name"

    def test_name_with_apostrophe(self):
        """Test slug from name with apostrophe."""
        assert BaseRepository.generate_slug("John's Device") == "john-s-device"

    def test_name_with_ampersand(self):
        """Test slug from name with ampersand."""
        assert BaseRepository.generate_slug("Living & Dining") == "living-dining"
