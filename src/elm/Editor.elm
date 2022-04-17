module Editor exposing (..)

import Browser exposing (Document, UrlRequest(..))
import Browser.Navigation as Nav
import Delay exposing (TimeUnit(..))
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode exposing (Decoder, field)
import Json.Encode as Encode
import RemoteData exposing (RemoteData(..), WebData)
import Url exposing (Url)



-- MAIN


main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlRequest = LinkClicked
        , onUrlChange = UrlChanged
        }



-- MODEL


type EditPreview
    = Edit
    | Preview


type BodyView
    = HtmlBody
    | TextBody


type SaveState
    = CanSave
    | Saving
    | Saved


type alias Model =
    { navKey : Nav.Key
    , url : Url
    , creatingOrUpdating : CreateOrUpdateTemplate
    , template : WebData Template
    , editPreview : EditPreview
    , bodyView : BodyView
    , parameters : String
    , saving : SaveState
    }


type CreateOrUpdateTemplate
    = Updating
    | Creating


type alias Template =
    { templateId : Int
    , name : String
    , alias : Maybe String
    , active : Bool
    , htmlBody : String
    , textBody : String
    , subject : String
    }


emptyTemplate : Template
emptyTemplate =
    Template -1 "" Nothing False "" "" ""


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url navKey =
    let
        maybeTemplateId =
            Maybe.andThen getTemplateId url.query

        ( cOrU, template, command ) =
            case maybeTemplateId of
                Just templateId ->
                    ( Updating, Loading, getTemplate templateId )

                Nothing ->
                    ( Creating, Success emptyTemplate, Cmd.none )
    in
    ( { navKey = navKey, url = url, creatingOrUpdating = cOrU, template = template, editPreview = Edit, bodyView = HtmlBody, parameters = "{}", saving = CanSave }, command )


getTemplateId : String -> Maybe Int
getTemplateId query =
    let
        findTemplateId : String -> Maybe Int
        findTemplateId segment =
            case String.split "=" segment of
                [ "templateId", value ] ->
                    String.toInt value

                _ ->
                    Nothing

        templateId =
            List.filterMap findTemplateId (String.split "&" query)
    in
    List.head templateId



-- UPDATE


type Msg
    = LinkClicked UrlRequest
    | UrlChanged Url
    | GotTemplate (WebData Template)
    | UpdateTemplate Template
    | UpdatedTemplate (WebData Template)
    | CreateTemplate Template
    | CreatedTemplate (Result Http.Error Template)
    | PreviewMsg
    | EditMsg
    | HtmlBodyMsg
    | TextBodyMsg
    | UpdateName String
    | UpdateSubject String
    | UpdateHtmlBody String
    | UpdateTextBody String
    | UpdateParameters String
    | SetSaved
    | SetCanSave


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Internal url) ->
            ( model, Nav.pushUrl model.navKey (Url.toString url) )

        LinkClicked (External url) ->
            ( model, Nav.load url )

        UrlChanged url ->
            ( { model | url = url }, Cmd.none )

        GotTemplate response ->
            ( { model | template = response }, Cmd.none )

        UpdatedTemplate response ->
            -- TODO: If response fails we should not be pretending things saved
            ( { model | template = response }, Delay.after 500 Millisecond SetSaved )

        SetSaved ->
            ( { model | saving = Saved }, Delay.after 2000 Millisecond SetCanSave )

        SetCanSave ->
            ( { model | saving = CanSave }, Cmd.none )

        CreatedTemplate response ->
            case response of
                Err e ->
                    -- should display an error to user that could not save
                    ( model, Cmd.none )

                Ok template ->
                    let
                        url =
                            model.url

                        withIdUrl =
                            { url | query = Just ("templateId=" ++ String.fromInt template.templateId) }
                    in
                    ( { model | template = Success template, creatingOrUpdating = Updating }, Cmd.batch [ Delay.after 500 Millisecond SetSaved, Nav.replaceUrl model.navKey <| Url.toString withIdUrl ] )

        UpdateTemplate template ->
            ( { model | saving = Saving }, updateTemplate template )

        CreateTemplate template ->
            ( { model | saving = Saving }, createTemplate template )

        PreviewMsg ->
            ( { model | editPreview = Preview }, Cmd.none )

        EditMsg ->
            ( { model | editPreview = Edit }, Cmd.none )

        HtmlBodyMsg ->
            ( { model | bodyView = HtmlBody }, Cmd.none )

        TextBodyMsg ->
            ( { model | bodyView = TextBody }, Cmd.none )

        UpdateName updatedName ->
            updateTemplateFromMsg (\t -> { t | name = updatedName }) model

        UpdateSubject updatedSubject ->
            updateTemplateFromMsg (\t -> { t | subject = updatedSubject }) model

        UpdateHtmlBody updatedHtmlBody ->
            updateTemplateFromMsg (\t -> { t | htmlBody = updatedHtmlBody }) model

        UpdateTextBody updatedTextBody ->
            updateTemplateFromMsg (\t -> { t | textBody = updatedTextBody }) model

        UpdateParameters updatedParameters ->
            ( { model | parameters = updatedParameters }, Cmd.none )


updateTemplateFromMsg : (Template -> Template) -> Model -> ( Model, Cmd Msg )
updateTemplateFromMsg updateFunc model =
    let
        ( template, cmd ) =
            RemoteData.update (\t -> ( updateFunc t, Cmd.none )) model.template
    in
    ( { model | template = template }, cmd )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Editor", body = [ viewBody model ] }


viewBody : Model -> Html Msg
viewBody model =
    section [ class "section all-height" ]
        [ div [ class "container all-height" ]
            [ viewModel model ]
        ]


viewModel : Model -> Html Msg
viewModel model =
    case model.template of
        NotAsked ->
            text "Initialising"

        Loading ->
            text "Loading template"

        Failure err ->
            text "Failed to get the template."

        Success template ->
            case model.creatingOrUpdating of
                Creating ->
                    viewCreateTemplate template model.editPreview model.bodyView model.parameters model.saving

                Updating ->
                    viewUpdateTemplate template model.editPreview model.bodyView model.parameters model.saving


viewCreateTemplate : Template -> EditPreview -> BodyView -> String -> SaveState -> Html Msg
viewCreateTemplate template editPreview bodyPreview parameters saving =
    viewTemplate template editPreview bodyPreview parameters CreateTemplate saving


viewUpdateTemplate : Template -> EditPreview -> BodyView -> String -> SaveState -> Html Msg
viewUpdateTemplate template editPreview bodyPreview parameters saving =
    viewTemplate template editPreview bodyPreview parameters UpdateTemplate saving


viewTemplate : Template -> EditPreview -> BodyView -> String -> (Template -> Msg) -> SaveState -> Html Msg
viewTemplate template editPreview bodyPreview parameters onClickMsg saving =
    div [ class "all-height" ]
        [ div [ class "columns" ]
            [ div [ class "column" ]
                [ div [ class "field" ]
                    [ label [ class "label" ] [ text "Template Name" ]
                    , div [ class "control" ] [ input [ class "input", type_ "text", value template.name, onInput UpdateName ] [] ]
                    ]
                ]
            , div [ class "column is-three-fifths" ]
                [ div [ class "field" ]
                    [ label [ class "label" ] [ text "Subject" ]
                    , div [ class "control" ] [ input [ class "input", type_ "text", value template.subject, onInput UpdateSubject ] [] ]
                    ]
                ]
            , div [ class "column is-narrow", style "margin-top" "auto" ]
                [ div [ class "control" ]
                    [ viewSaveButton template onClickMsg saving ]
                ]
            ]
        , editPreviewTabs editPreview
        , htmlTextTabs bodyPreview
        , viewContents template editPreview bodyPreview parameters
        ]


viewSaveButton : Template -> (Template -> Msg) -> SaveState -> Html Msg
viewSaveButton template onClickMsg saving =
    case saving of
        CanSave ->
            button [ class "button is-link is-pulled-right", onClick (onClickMsg template) ] [ text "Save" ]

        Saving ->
            button [ class "button is-link is-pulled-right is-loading" ] [ text "Save" ]

        Saved ->
            button [ class "button is-pulled-right" ] [ text "Saved" ]


viewContents : Template -> EditPreview -> BodyView -> String -> Html Msg
viewContents template editPreview bodyView parameters =
    case editPreview of
        Edit ->
            let
                ( templateValue, msg ) =
                    case bodyView of
                        HtmlBody ->
                            ( template.htmlBody, UpdateHtmlBody )

                        TextBody ->
                            ( template.textBody, UpdateTextBody )
            in
            textarea [ class "textarea", value templateValue, rows 20, onInput msg ] []

        Preview ->
            div [ class "columns all-height" ]
                [ div [ class "column is-two-thirds" ]
                    [ div [ class "box all-height" ]
                        [ viewPreview template bodyView parameters ]
                    ]
                , div [ class "column" ] [ viewParameterEditor parameters ]
                ]


viewPreview : Template -> BodyView -> String -> Html Msg
viewPreview template bodyView parameters =
    case bodyView of
        HtmlBody ->
            compileAndRunHtml template.htmlBody parameters

        --iframe
        --    [ srcdoc template.htmlBody
        --    , attribute "frameborder" "0"
        --    , attribute "allowfullscreen" ""
        --    , style "width" "100%"
        --    , style "height" "100%"
        --    ]
        --    []
        TextBody ->
            compileAndRunText template.textBody parameters


viewParameterEditor : String -> Html Msg
viewParameterEditor parameters =
    textarea [ class "textarea all-height", value parameters, onInput UpdateParameters, placeholder "Your parameters" ] []


compileAndRunHtml : String -> String -> Html Msg
compileAndRunHtml template parameters =
    -- The `is` mechanism with custom element is not supported in Elm: https://github.com/elm/virtual-dom/issues/156.
    -- iframe [ attribute "is" "handlebars-html-iframe", attribute "template" template, attribute "parameters" parameters ] []
    node "handlebars-html-iframe2" [ attribute "template" template, attribute "parameters" parameters ] []


compileAndRunText : String -> String -> Html Msg
compileAndRunText template parameters =
    node "handlebars-text" [ attribute "template" template, attribute "parameters" parameters ] []


editPreviewTabs : EditPreview -> Html Msg
editPreviewTabs editPreview =
    case editPreview of
        Edit ->
            div [ class "tabs is-boxed" ]
                [ ul []
                    [ li [ class "is-active" ] [ a [ href "#" ] editTab ] -- can be real fancy and make the fragment show which tab we are on #edit-html maybe?
                    , li [] [ a [ onClick PreviewMsg, href "#" ] previewTab ]
                    ]
                ]

        Preview ->
            div [ class "tabs is-boxed" ]
                [ ul []
                    [ li [] [ a [ onClick EditMsg, href "#" ] editTab ]
                    , li [ class "is-active" ] [ a [ href "#" ] previewTab ]
                    ]
                ]


editTab : List (Html Msg)
editTab =
    [ span [ class "icon is-small" ] [ i [ class "fas fa-pencil-alt", attribute "aria-hidden" "true" ] [] ], span [] [ text "Edit" ] ]


previewTab : List (Html Msg)
previewTab =
    [ span [ class "icon is-small" ] [ i [ class "fas fa-eye", attribute "aria-hidden" "true" ] [] ], span [] [ text "Preview" ] ]


htmlTextTabs : BodyView -> Html Msg
htmlTextTabs bodyView =
    case bodyView of
        HtmlBody ->
            div [ class "tabs is-toggle is-small", style "padding-left" "1rem" ]
                [ ul []
                    [ li [ class "is-active" ] [ a [ href "#" ] [ text "HTML" ] ]
                    , li [] [ a [ onClick TextBodyMsg, href "#" ] [ text "Text" ] ]
                    ]
                ]

        TextBody ->
            div [ class "tabs is-toggle is-small", style "padding-left" "1rem" ]
                [ ul []
                    [ li [] [ a [ onClick HtmlBodyMsg, href "#" ] [ text "HTML" ] ]
                    , li [ class "is-active" ] [ a [ href "#" ] [ text "Text" ] ]
                    ]
                ]



-- HTTP


getTemplate : Int -> Cmd Msg
getTemplate templateId =
    Http.get
        { url = "/templates/" ++ String.fromInt templateId
        , expect = Http.expectJson (RemoteData.fromResult >> GotTemplate) templateDecoder
        }


templateDecoder : Decoder Template
templateDecoder =
    Decode.map7 Template
        (field "templateId" Decode.int)
        (field "name" Decode.string)
        (field "alias" (Decode.nullable Decode.string))
        (field "active" Decode.bool)
        (field "htmlBody" Decode.string)
        (field "textBody" Decode.string)
        (field "subject" Decode.string)


updateTemplate : Template -> Cmd Msg
updateTemplate template =
    Http.request
        { method = "PUT"
        , headers = []
        , url = "/templates/" ++ String.fromInt template.templateId
        , body = Http.jsonBody (templateUpdateEncode template)
        , expect = Http.expectJson (RemoteData.fromResult >> UpdatedTemplate) templateDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


createTemplate : Template -> Cmd Msg
createTemplate template =
    Http.post
        { url = "/templates"
        , body = Http.jsonBody (templateCreateEncode template)
        , expect = Http.expectJson CreatedTemplate templateDecoder
        }


templateCreateEncode : Template -> Encode.Value
templateCreateEncode template =
    Encode.object <| ( "alias", encodeMaybeString template.alias ) :: templateCommonFields template


templateUpdateEncode : Template -> Encode.Value
templateUpdateEncode template =
    Encode.object <| templateCommonFields template


templateCommonFields : Template -> List ( String, Encode.Value )
templateCommonFields template =
    [ ( "name", Encode.string template.name )
    , ( "subject", Encode.string template.subject )
    , ( "textBody", Encode.string template.textBody )
    , ( "htmlBody", Encode.string template.htmlBody )
    ]


encodeMaybeString : Maybe String -> Encode.Value
encodeMaybeString maybe =
    case maybe of
        Just s ->
            Encode.string s

        Nothing ->
            Encode.null
