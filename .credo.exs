%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "test/", "priv/repo/migrations/"],
        excluded: []
      },
      checks: [
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, [parens: true]},
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
        {Credo.Check.Warning.LazyLogging, false},

        # handled by mix format check
        {Credo.Check.Consistency.LineEndings, false},
        {Credo.Check.Consistency.SpaceAroundOperators, false},
        {Credo.Check.Consistency.SpaceInParentheses, false},
        {Credo.Check.Consistency.TabsOrSpaces, false},
        {Credo.Check.Readability.LargeNumbers, false},
        {Credo.Check.Readability.MaxLineLength, false},
        {Credo.Check.Readability.RedundantBlankLines, false},
        {Credo.Check.Readability.SpaceAfterCommas, false},
        {Credo.Check.Readability.TrailingBlankLine, false},
        {Credo.Check.Readability.TrailingWhiteSpace, false}
      ]
    }
  ]
}
