local files = require('shooter.core.files')

describe('shooter.core.files slugify', function()
  describe('slugify_segment', function()
    it('replaces spaces with dashes', function()
      assert.equals('some-file', files.slugify_segment('some file'))
    end)

    it('lowercases', function()
      assert.equals('foo-bar', files.slugify_segment('Foo Bar'))
    end)

    it('strips non-alnum characters', function()
      assert.equals('foo-bar', files.slugify_segment('foo & bar!'))
    end)

    it('collapses repeated dashes', function()
      assert.equals('foo-bar', files.slugify_segment('foo   bar'))
      assert.equals('foo-bar', files.slugify_segment('foo---bar'))
    end)

    it('trims leading/trailing dashes', function()
      assert.equals('foo', files.slugify_segment('- foo -'))
    end)

    it('returns empty for empty input', function()
      assert.equals('', files.slugify_segment(''))
    end)
  end)

  describe('slugify_path', function()
    it('slugifies each segment', function()
      assert.equals('some/folder/some-file',
        files.slugify_path('some/folder/some file'))
    end)

    it('preserves trailing slash', function()
      assert.equals('some/folder/',
        files.slugify_path('some/folder/'))
    end)

    it('handles mixed spacing across segments', function()
      assert.equals('my-app/next/user-flow',
        files.slugify_path('My App/next/User Flow'))
    end)

    it('returns empty for empty input', function()
      assert.equals('', files.slugify_path(''))
    end)
  end)

  describe('generate_filename', function()
    it('returns slug.md', function()
      assert.equals('some-file.md', files.generate_filename('Some File'))
    end)
  end)
end)
