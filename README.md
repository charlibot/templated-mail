# Templated Mail API

Service to upload and edit template resources for emails.
Templates can be parameterised using Mustache.
Can also send emails with contents generated from the templates.

## Template versions

This API is similar to [Postmarks](https://postmarkapp.com/developer/api/templates-api) which does not have a concept of template versions.
Sendgrid does.
The benefit of a template having multiple versions is that you can change them without
having to update the config of the application using the template.

## With renderings

When uploading a template it has an alias.
Use the alias to make rendering calls.

TODO: The email render response from existing template should contain the From email address and display name.
Templates do not naturally provide these parameters so these values need to come from somewhere if we want to keep the backward compatibility.

TODO: How to do accept-language? Ignored atm. 
My guess is one template per language and let the application select the appropriate one.

### To run

`elm make src/elm/Main.elm --output src/main/resources/public/elm.js`

`elm make src/elm/Editor.elm --output src/main/resources/public/editor.js`

`./gradlew bootRun`

### To docker

`./gradlew jib --image=...`

### To use

Visit http://localhost:8080 in a browser for the UI or use the API directly:

#### Create a template

```
curl localhost:8080/templates \
  -X POST \
  -d '{
          "name": "Welcome Email",
          "htmlBody": "<html><body>Hello {{name}}<body><html>",
          "textBody": "Hello, {{name}}",
          "subject": "Hello, from {{company.name}}",
          "alias": "welcome/email"
      }'
```

or with Httpie

```
http POST localhost:8080/templates name="Welcome Email" \
  htmlBody="<html><body>Hello {{name}}<body><html>" \
  textBody="Hello, {{name}}" \
  subject="Hello, from {{company.name}}" \
  alias="welcome/email"
```

#### Get all templates:

`curl localhost:8080/templates`

#### Get a specific template

`curl localhost:8080/templates/1`

#### Send an email with the template

```
curl "localhost:8080/email/withTemplate" \
  -X POST \
  -d '{
          "from": "templatedmail@example.com",
          "to": "${USER}@example.com",
          "templateId": 1,
          "templateModel": {
              "name": "John Smith",
              "company": {
                "name": "ExampleCorp"
              }
          }
      }'
```

or with Httpie

```
http POST localhost:8080/email/withTemplate \
  from="templatedmail@example.com" \
  to="${USER}@example.com" \
  templateId:=1 \
  templateModel:='{"name": "John Smith", "company": { "name": "ExampleCorp" }}'
```

##### Rendering

Send PUT requests to `/v1/renderings/{templateAlias}` to render email contents.
The body of the request should contain values for the parameters in the template.

e.g.

```
http PUT localhost:8080/v1/renderings/welcome/email \
  name="John Smith" \
  company:='{"name": "ExampleCorp"}' 
```


### Elm UI

Wanted to use Elm to make a copy of https://postmarkapp.com/images/reasons/TemplateEdit.png. 

#### Some notes:

- Would be nice if gradle compiled the elm files and move the .js files to resources/public.
- Moving from the home page to a template editor page is not legitimate. The editor template ID is hard coded. A SPA would be nice.
- Wanted to use [Ace code editor](https://github.com/ajaxorg/ace). Some related links that I found:
  - https://github.com/RobertWalter83/calliope/blob/master/src/js/interop.js
  - https://discourse.elm-lang.org/t/examples-of-using-codemirror-ace-monaco-text-editors-in-elm-apps/2797
  - https://github.com/lukewestby/elm-codegen-preview/tree/master
  - https://github.com/LostInBrittany/ace-widget
  - https://package.elm-lang.org/packages/billstclair/elm-custom-element/latest/CustomElement-CodeEditor
  - To get this working ended up using https://github.com/Juicy/juicy-ace-editor. This requires `juicy-ace-editor.html` 
    in the public resources folder and webcomponents-lite.js to be brought in on the editor page.
- Used [Bulma](https://bulma.io) to style
- Could use MJML as an optional language and let the service transpile to HTML
- Could use cloud functions. Maybe use https://github.com/the-sett/elm-serverless to go full Elm.
