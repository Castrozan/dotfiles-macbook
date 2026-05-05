<h2 align="center"><a href="https://github.com/Castrozan" target="_blank" rel="noopener noreferrer">Zanoni's</a> Macbook Configs</h2>

<p align="center">
  <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/palette/macchiato.png" width="400" />
</p>

<p align="center">
   <a href="https://github.com/Castrozan/dotfiles-macbook/actions/workflows/tests.yml">
      <img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Castrozan/dotfiles-macbook/tests.yml?style=for-the-badge&amp;logo=github-actions&amp;color=A6E3A1&amp;logoColor=D9E0EE&amp;labelColor=302D41&amp;label=CI">
   </a>
   <a href="https://github.com/Castrozan/dotfiles-macbook/actions/workflows/nix-lint.yml">
      <img alt="Nix Lint" src="https://img.shields.io/github/actions/workflow/status/Castrozan/dotfiles-macbook/nix-lint.yml?style=for-the-badge&amp;logo=nixos&amp;color=89B4FA&amp;logoColor=D9E0EE&amp;labelColor=302D41&amp;label=Nix%20Lint">
   </a>
   <img alt="Stargazers" src="https://img.shields.io/github/stars/Castrozan/dotfiles-macbook?style=for-the-badge&amp;logo=starship&amp;color=C9CBFF&amp;logoColor=D9E0EE&amp;labelColor=302D41">
   <a href="https://github.com/nix-darwin/nix-darwin">
      <img src="https://img.shields.io/badge/nix--darwin-25.11-informational.svg?style=for-the-badge&amp;logo=apple&amp;color=F2CDCD&amp;logoColor=D9E0EE&amp;labelColor=302D41">
   </a>
</p>

Welcome to my macbook dotfiles! This repository contains my Apple Silicon laptop setup using **nix-darwin** + **home-manager**, with Claude Code agent infrastructure baked in. macOS only - the NixOS/Linux side lives in [castrozan/.dotfiles](https://github.com/castrozan/.dotfiles).

---

## Getting Started

<details>
<summary>
   <b>Quick Start for: 🍎 Apple Silicon Macbook</b>
</summary>

#### 1. Install Nix
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

#### 2. Clone the Repository
```bash
cd ~
git clone https://github.com/Castrozan/dotfiles-macbook.git .dotfiles
cd .dotfiles
```

#### 3. Customize Your Configuration
- Copy and modify `users/lucas.zanoni/` to your username
- Update `flake.nix` to add your configuration in `darwinConfigurations`
- Update `users.users.${username}` block in `hosts/macbook/default.nix` if needed

#### 4. Bootstrap nix-darwin
```bash
sudo nix run nix-darwin -- switch --flake .#macbook
```

#### 5. Subsequent rebuilds
```bash
darwin-rebuild switch --flake .#macbook
```
or use the wrapper:
```bash
./hosts/macbook/scripts/rebuild
```

</details>

---

## 🔗 Inspiration & Credits

This setup is inspired by and borrows from:
- <a href="https://github.com/Castrozan/.dotfiles" target="_blank" rel="noopener noreferrer">castrozan/.dotfiles</a> - The NixOS/Linux sibling of this repo
- <a href="https://github.com/ryan4yin/nix-config" target="_blank" rel="noopener noreferrer">ryan4yin/nix-config</a> - Excellent complex Nix configurations
- The amazing nix-darwin and Home Manager communities
- And countless other dotfiles repos I've stumbled upon at 3 AM 🌙

## 📚 Resources

- <a href="https://nix-darwin.github.io/nix-darwin/manual/" target="_blank" rel="noopener noreferrer">nix-darwin Manual</a> - Official documentation
- <a href="https://nix-community.github.io/home-manager/" target="_blank" rel="noopener noreferrer">Home Manager Manual</a> - Home Manager docs
- <a href="https://nixos.org/guides/nix-pills/" target="_blank" rel="noopener noreferrer">Nix Pills</a> - Learn Nix the fun way
- <a href="https://github.com/ryan4yin/nixos-and-flakes-book" target="_blank" rel="noopener noreferrer">NixOS & Flakes Book</a> - Comprehensive guide

---

Enjoy ricing and happy hacking! If you like this setup, consider giving it a ⭐
