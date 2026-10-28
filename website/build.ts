import tailwind from "bun-plugin-tailwind";

const result = await Bun.build({
  entrypoints: ["./index.html"],
  outdir: "./dist",
  minify: true,
  plugins: [tailwind],
});

if (!result.success) {
  for (const log of result.logs) console.error(log);
  process.exit(1);
}

// Link previews need a stable URL, so the OG image is copied without a content hash.
await Bun.write("./dist/og.png", Bun.file("./og.png"));
