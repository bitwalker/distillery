[
  inputs: [
    "lib/**/*.ex",
    "test/**/*.{ex, exs}",
  ],
  export: [
    locals_without_parens: [
      release: 2,
      environment: 2,
      plugin: 2,
      command: 2,
      command: 3,
      command: 4,
      option: 2,
      option: 3,
      option: 4,
      require_global: 1,
      set: 1
    ]
  ]
]
