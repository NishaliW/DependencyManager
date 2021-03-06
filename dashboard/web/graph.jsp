<%@page import="java.sql.*"%>
<%@page import="java.sql.Connection"%>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.HashMap" %>
<%!
    public static int MAX_RECUSION_DEPTH = 2;
    private static HashMap<String, ArrayList<String>> nodes;

    public String loadJson(String graphType, String repositoryName, String isSnapshots, String json) {
        try {
            Class.forName("com.mysql.jdbc.Driver");
            Connection con = DriverManager.getConnection(
                    "jdbc:mysql://localhost:3306/DependencyManager", "root",
                    "Root@wso2");
            Statement st = con.createStatement();

            String query;

            if (graphType.equals("artifacts")) {
            query = "SELECT DISTINCT r.RepoName As DependRepo , " +
                    "CONCAT(rr.RepoName,' (',d.GroupId,':',d.ArtifactId,':',d.Version,')') AS SourceArtifact" +
                    " FROM (DependencyManager.RepositoryTable r JOIN DependencyManager.RepositoryDependencyTable rd " +
                    "ON r.RepoID = rd.DependRepoId) JOIN DependencyManager.DependencyTable d " +
                    "ON rd.ArtifactID = d.ArtifactId AND rd.GroupId = d.GroupId AND rd.Version = d.Version " +
                    "JOIN DependencyManager.RepositoryTable rr ON d.SourceRepoId = rr.RepoID " +
                    "WHERE r.RepoName != rr.RepoName";
            } else {
            query = "SELECT DISTINCT r.RepoName AS DependRepo , rr.RepoName AS SourceRepo " +
                    "FROM (DependencyManager.RepositoryTable r JOIN DependencyManager.RepositoryDependencyTable rd " +
                    "ON r.RepoID = rd.DependRepoId) JOIN DependencyManager.DependencyTable d " +
                    "ON rd.ArtifactID = d.ArtifactId AND rd.GroupId = d.GroupId AND rd.Version = d.Version " +
                    "JOIN DependencyManager.RepositoryTable rr ON d.SourceRepoId = rr.RepoID " +
                    "WHERE r.RepoName != rr.RepoName";
            }

            if (isSnapshots.equals("true")) {
                query += " AND d.Version LIKE '%snapshot%'";
            }

            ResultSet rs = st.executeQuery(query);

             nodes = new HashMap<String, ArrayList<String>>();

            while (rs.next()) {

                if (!repositoryName.equals("")){
                    ArrayList<String> dep =  nodes.get(rs.getString(1));

                    if (dep == null){
                        dep = new ArrayList<String>();
                    }

                    dep.add(rs.getString(2));

                    nodes.put(rs.getString(1), dep);
                }
                else {
                    json += '"' + rs.getString(1) + '"' + "->" + '"'
                            + rs.getString(2) + '"' + ";";

                }
            }

            st.close();
            con.close();

            if (!repositoryName.equals("")) {
                json += constructJson(repositoryName, 0);
            }

            System.out.println(json);

        } catch (Exception ex) {
            System.out.println(ex.getMessage());
        }

        return json;
    }

    private String constructJson(String repoName, int count) {

        String json = "";
        ArrayList<String> dep =nodes.get(repoName);

        if (dep != null){
            for (int i = 0; i  < dep.size(); i++){
                    json += '"' + repoName + '"' + "->" + '"'
                            + dep.get(i) + '"' + ";";
                       if ( count < MAX_RECUSION_DEPTH) {
                            json += constructJson(dep.get(i), count + 1);
                        }
            }
        }

        return  json;
    }
%>

<html>
<head>

    <meta charset="utf-8">
    <title>Dependency Graph</title>
    <link type="text/css" rel="stylesheet" href="css/main.css" />
    <script type="text/javascript" src="js/d3.v3.js"></script>
    <script type="text/javascript" src="js/graphlib-dot.js"></script>
    <script type="text/javascript" src="js/dagre-d3.js"></script>

    <style type="text/css">
        svg {
            border: 1px solid #999;
            overflow: hidden;
        }

        .node {
            white-space: nowrap;
        }

        .node rect,
        .node circle,
        .node ellipse {
            stroke: #333;
            fill: #fff;
            stroke-width: 1.5px;
        }

        .cluster rect {
            stroke: #333;
            fill: #000;
            fill-opacity: 0.1;
            stroke-width: 1.5px;
        }

        .edgePath path.path {
            stroke: #333;
            stroke-width: 1.5px;
            fill: none;
        }
    </style>

    <style>
        h1, h2 {
            color: #333;
        }

        textarea {
            width: 800px;
        }

        label {
            margin-top: 1em;
            display: block;
        }

        .error {
            color: red;
        }
    </style>
</head>


<body onLoad="tryDraw();">

<%
    String json = "digraph {" + loadJson(request.getParameter("graphType"), request.getParameter("repositoryName"),
            request.getParameter("snapshots"), "") + "}";

%>

<form>
    <textarea id="inputGraph" rows="5" style="display: block" onKeyUp="tryDraw();"/></textarea>
    <a id="graphLink">Link for this graph</a>
    <script type="text/javascript">
        document.getElementById("inputGraph").value = '<%out.print(json);%>';
        document.getElementById("inputGraph").style.display = "none";
        document.getElementById("graphLink").style.display = "none";
    </script>
</form>

<svg width=100% height=600>
    <g/>
</svg>

<script type="text/javascript">
    function graphToURL() {
        var elems = [window.location.protocol, '//',
            window.location.host,
            window.location.pathname,
            '?'];

        var queryParams = [];
        if (debugAlignment) {
            queryParams.push('alignment=' + debugAlignment);
        }
        queryParams.push('graph=' + encodeURIComponent(inputGraph.value));
        elems.push(queryParams.join('&'));

        return elems.join('');
    }

    var inputGraph = document.querySelector("#inputGraph");

    var graphLink = d3.select("#graphLink");

    var oldInputGraphValue;

    var graphRE = /[?&]graph=([^&]+)/;
    var graphMatch = window.location.search.match(graphRE);
    if (graphMatch) {
        inputGraph.value = decodeURIComponent(graphMatch[1]);
    }
    var debugAlignmentRE = /[?&]alignment=([^&]+)/;
    var debugAlignmentMatch = window.location.search.match(debugAlignmentRE);
    var debugAlignment;
    if (debugAlignmentMatch) debugAlignment = debugAlignmentMatch[1];

    // Set up zoom support
    var svg = d3.select("svg"),
            inner = d3.select("svg g"),
            zoom = d3.behavior.zoom().on("zoom", function() {
                inner.attr("transform", "translate(" + d3.event.translate + ")" +
                        "scale(" + d3.event.scale + ")");
            });
    svg.call(zoom);

    // Create and configure the renderer
    var render = dagreD3.render();

    function tryDraw() {
        var g;
        if (oldInputGraphValue !== inputGraph.value) {
            inputGraph.setAttribute("class", "");
            oldInputGraphValue = inputGraph.value;
            try {
                g = graphlibDot.read(inputGraph.value);
            } catch (e) {
                inputGraph.setAttribute("class", "error");
                throw e;
            }

            // Save link to new graph
            graphLink.attr("href", graphToURL());

            // Set margins, if not present
            if (!g.graph().hasOwnProperty("marginx") &&
                    !g.graph().hasOwnProperty("marginy")) {
                g.graph().marginx = 20;
                g.graph().marginy = 20;
            }

            g.graph().transition = function(selection) {
                return selection.transition().duration(500);
            };

            // Render the graph into svg g
            d3.select("svg g").call(render, g);
        }
    }
</script>

</body>

</html>
