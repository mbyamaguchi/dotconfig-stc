package main

import "testing"

// Fixtures captured from the actual tools on this machine. The point of these is
// that "take the first line" and "take the last number" both fail on real output.
func TestExtractVersion(t *testing.T) {
	cases := []struct{ name, out, want string }{
		{
			// eza puts no digits on line 1 at all.
			"eza",
			"eza - A modern, maintained replacement for ls\nv0.23.5 [+git]\nhttps://github.com/eza-community/eza",
			"0.23.5",
		},
		{
			// Line 2 is rustc's version, not sheldon's.
			"sheldon",
			"sheldon 0.8.5 (344dfc75e 2025-07-22)\nrustc 1.88.0 (6b00bc388 2025-06-23)",
			"0.8.5",
		},
		{"go", "go version go1.22.2 linux/amd64", "1.22.2"},
		{"go pinned", "go version go1.26.5 linux/amd64", "1.26.5"},
		{"node", "v24.15.0", "24.15.0"},
		{"fzf", "0.74.1 (eae8d9d2)", "0.74.1"},
		{"nvim", "NVIM v0.12.3\nBuild type: Release\nLuaJIT 2.1.1713773202", "0.12.3"},
		{"yt-dlp", "2026.03.17", "2026.03.17"},
		{"uv", "uv 0.11.29 (x86_64-unknown-linux-gnu)", "0.11.29"},
		{"pixi", "pixi 0.67.2", "0.67.2"},
		{"starship", "starship 1.25.1", "1.25.1"},
		{"stylua", "stylua 2.5.2", "2.5.2"},
		{"bob", "bob-nvim 4.1.7", "4.1.7"},
		{"cargo", "cargo 1.97.1 (c980f4866 2026-06-30)", "1.97.1"},
		{"no version at all", "command not found", ""},
		{"empty", "", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := ExtractVersion(c.out); got != c.want {
				t.Errorf("ExtractVersion(%q) = %q, want %q", c.out, got, c.want)
			}
		})
	}
}

func TestCompareVersions(t *testing.T) {
	cases := []struct {
		a, b string
		want int
	}{
		// The one a string comparison gets backwards, and the reason this
		// function exists: an apt zoxide 0.9.3 passed for a pinned 0.10.0.
		{"0.10.0", "0.9.3", 1},
		{"0.9.3", "0.10.0", -1},
		{"1.10.0", "1.9.9", 1},
		{"2.0.0", "10.0.0", -1},

		{"1.2.3", "1.2.3", 0},
		{"1.2", "1.2.0", 0}, // shorter is zero-padded
		{"1.2.1", "1.2", 1},

		{"v1.2.3", "1.2.3", 0}, // leading v is not significant
		{"1.2.3", "v1.2.3", 0},

		// yt-dlp's date-shaped versions still order correctly.
		{"2026.03.17", "2026.07.04", -1},
		{"2026.07.04", "2026.03.17", 1},

		{"1.2.3-rc1", "1.2.3", 0}, // pre-release suffix is ignored, not fatal
	}
	for _, c := range cases {
		if got := CompareVersions(c.a, c.b); got != c.want {
			t.Errorf("CompareVersions(%q, %q) = %d, want %d", c.a, c.b, got, c.want)
		}
	}
}

func TestAtLeast(t *testing.T) {
	cases := []struct {
		a, b string
		want bool
	}{
		{"0.74.1", "0.48.0", true},  // the fzf --zsh contract
		{"0.44.1", "0.48.0", false}, // noble's fzf, which breaks .zshrc
		{"0.9.3", "0.9.4", false},
		{"0.10.0", "0.9.4", true},
		{"1.2.3", "1.2.3", true},
		{"", "1.0.0", false}, // unknown is never good enough
		{"1.0.0", "", false},
	}
	for _, c := range cases {
		if got := AtLeast(c.a, c.b); got != c.want {
			t.Errorf("AtLeast(%q, %q) = %v, want %v", c.a, c.b, got, c.want)
		}
	}
}

func TestNeedsInstall(t *testing.T) {
	cases := []struct {
		name, cur, ref, min string
		want                bool
	}{
		{"exact pin matches", "0.23.5", "v0.23.5", "0.20.0", false},
		{"exact pin behind", "0.23.4", "v0.23.5", "0.20.0", true},
		// Newer than the pin is drift too: the goal is reproducibility, not
		// "at least". This is deliberate and differs from a >= check.
		{"exact pin ahead", "0.24.0", "v0.23.5", "0.20.0", true},
		{"tag without v", "0.8.5", "0.8.5", "0.7.0", false},

		{"floating above min", "2026.07.04", "latest", "-", false},
		{"floating with min met", "0.74.1", "latest", "0.48.0", false},
		{"floating below min", "0.44.1", "latest", "0.48.0", true},

		{"not installed", "", "v1.0.0", "-", true},
		{"not installed, floating", "", "latest", "-", true},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := NeedsInstall(c.cur, c.ref, c.min); got != c.want {
				t.Errorf("NeedsInstall(%q, %q, %q) = %v, want %v", c.cur, c.ref, c.min, got, c.want)
			}
		})
	}
}
