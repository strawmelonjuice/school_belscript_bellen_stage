# Belhulp bij je stage

[![Package Version](https://img.shields.io/hexpm/v/belhulp_bellen_stage)](https://hex.pm/packages/belhulp_bellen_stage)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/belhulp_bellen_stage/)

## About

My school suffers immensely from antisocial IT students, which only makes sense.
Now, this is a small thing I spun up to give them a bit of _guidance_ while calling
companies for internships, because that one seems to be hardest.

I am Dutch, so the content is in Dutch. I will not translate it.
You could edit the `stappen` function to import a new script, though.

## Usage

I pre-generate with Lustre, so GitHub Pages will do the serving.
Should be available at:
<https://strawmelonjuice.github.io/school_belscript_bellen_stage/>

## Development

```sh
bun i # Install DaisyUI and other deps.
gleam run -m lustre/dev start # Start the Lustre dev tools server
```
